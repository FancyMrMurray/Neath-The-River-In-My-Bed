<CsoundSynthesizer>
<CsOptions>
-odac
-iadc
-Ma
</CsOptions>
<CsInstruments>

sr = 44100
ksmps = 64
nchnls = 2
nchnls_i = 1
0dbfs = 1

giAttenuation 			init 0.5											;Global Attenuation Constant

gaTapeL					init 0												;initialize the Tape Aux-Bus (left channel)
gaTapeR					init 0												;initialize the Tape Aux-Bus (right channel)

gaMasterL					init 0												;initialize the Master Aux-Bus (left channel)
gaMasterR					init 0												;initialize the Master Aux-Bus (right channel)

							massign 1, 2										;sends MIDI channel 1 data to instr 2

instr 1 																		;instrument 1 - the tape machine

	kFadeOut			 	invalue "CrossfadeTrigger"						;pull value from Crossfade Trigger button (on or off)

	kTapeEnv				linseg 0, 0.01, 0, 15, 1, 1, 1				;fade in and then hold the tape's volume
	
	gaTapeL, gaTapeR 	diskin "241005-131805 Cropped.wav"			;audio file in
	
	if kFadeOut			== 1 then											;if the FadeOut button is "on" then

		kTapeEnv	 		expseg 1, 60, 0.001, 1, 0.00001				;fade out the tape
							
	endif																		;end the if statement

							outvalue "TapeEnv", kTapeEnv					;display the Tape's amplification in the channel "TapeEnv"
			
	gaMasterL				= gaTapeL * kTapeEnv * giAttenuation			;Send the tape audio to the Master Aux-Bus (left channel)		
	gaMasterR				= gaTapeR * kTapeEnv * giAttenuation			;Send the tape audio to the Master Aux-Bus (left channel)
	
endin																			;end the instructions for instrumentt 1

instr 2 																		;instrument 2 - the filters: keyboard and pedalboard

	krel 					init 0												;initialise the release flag
	
	kRandNum				random 0, 1										;generate a stream of random number from 0 to 1

	iAttack				= 0.5												;set attack length
	iDecay					= 1.5												;set decay length
	iMasterAmplify		= 175												;set the amplification value for filtered audio

	iMidNum				notnum												;get the MIDI note number
	iOctNum				= int(iMidNum/12)-1								;calculate the octave number
	iPtchNum				table iMidNum, 1, 0, 0, 1						;calculate the pitch number (in 31-edo; see function 1)

	iFrq					= 440 * 2^((31*iOctNum+iPtchNum-155)/31)	;calculate frequency
	iBW						= iFrq/(400*((0.001*iFrq^1.7)/(0.001*iFrq^1.7+0.488)))	;calculate the bandwidth
	
	iFrqAmpTable			table (iOctNum * 31 + iPtchNum)/248, 5, 1, 0, 0	;calculate the frequency amp modifier (see function 2)
	iFrqAmpMod			=iFrqAmpTable * 8								;further calculate the frequency modifier

	a1						butterbp gaTapeL, iFrq, iBW					;apply the filter Left
	a2						butterbp gaTapeR, iFrq, iBW					;apply the filter right
	
							xtratim iDecay									;adds the Decay time to instance
							
  	krel 					release 											;sets the release flag to 1 upon release
  	
	if (krel == 1) 		kgoto rel											;if we are in the release of the envelope, goto 'rel:'

		kEnv1				linseg 0, 0.01, 0, iAttack, 1, 1, 1			;create attack-half of envelope
		kEnv				= kEnv1											;assign attack-half to variable
							kgoto 	bypassrel									;jump PAST the decay-half of the envelope to 'bypass rel:'
	
	rel:																		//rel:
	
		kEnv2				linseg 1, iDecay-0.01, 0, 0.01, 0				;create decay-half of envelope
		kEnv				= kEnv2											;assign decay-half to variable
	
	bypassrel:																//bypassrel:
	
	kVolumePed			ctrl7 1, 11, 0.001, 1, 2						;volume pedal, measured from 0.001 to 1 (because exp)
	
	kAmp					table kVolumePed, 2, 1, 0, 0					;calculate amp from exp curve
	
	gaMasterL				+= a1 * kAmp * kEnv * iFrqAmpMod *iMasterAmplify * giAttenuation	;send to master aux-bus
	gaMasterR				+= a2 * kAmp * kEnv * iFrqAmpMod * iMasterAmplify * giAttenuation	;send to master aux-bus
	
	kGrainPed				ctrl7 1, 19, 0.05, 1							;get the grain value from the pedal
	
	reinitialize:																//reinitialize:
	
	kGrainFrq				table kGrainPed, 3, 1, 0, 0					;calculate the grain frequency (call frequency not pitch frequency)
	
	kGrainLength			table kRandNum, 4, 1, 0, 0						;calculate grain length
	iPitchRatio			= int(i(kRandNum)*3+1)							;calculate the pitch ratio (which harmonic it is)
	iGrainPitch			= iPitchRatio * iFrq							;calculate frequency of the grain to be called
	
	timout 0, i(kGrainFrq), continue										;unless its time to call a grain skip to 'continue:'

							rireturn											;end the reinitialization here

							event "i", 3, 0, kGrainLength*(kGrainPed+0.1), iGrainPitch, iPitchRatio, kGrainPed	;call the grain instance
							
							reinit reinitialize								;go back to 'reinitialize:' and reinitialize until 'rireturn'
							
	continue:																	//continue:								
	
endin																			;end the instructions for instrument 2

instr 3																		;instrument 3 - grains

	iMasterAmplify		= 25												;set the master amplification

	iBW						= p4/(400*((0.001*p4^1.7)/(0.001*p4^1.7+0.488)))	;calculate bandwidth

	a1						butterbp gaTapeL, p4, iBW						;filter L
	a2						butterbp gaTapeR, p4, iBW						;filter R
	
	kEnv					linseg 0, 0.001, 0, (p3*.5)-0.002, 1, p3*.5, 0, 0.001, 0	;envelope
	
	gaMasterL				+= a1 * kEnv * iMasterAmplify * 1/p5 * (p6*0.5+0.5) * giAttenuation	;send to master aux-bus L
	gaMasterR				+= a2 * kEnv * iMasterAmplify * 1/p5 * (p6*0.5+0.5) * giAttenuation	;send to master aux-bus R
	
endin																			;end the instructions for instrument 3

instr 4																		;instrument 4 - the master channel fader & outs

	a1						compress2 gaMasterL, gaMasterL, -120, -6, -3, 10, 0.01, 0.1, 0.1	;compressor L (essentially a limiter)
	a2						compress2 gaMasterR, gaMasterR, -120, -6, -3, 10, 0.01, 0.1, 0.1	;compressor R (essentially a limiter)
	
	;a3,a4					ins													;if recording the piano to save to file, uncomment this line
																			
							fout "OUT.WAV", -1, a1, a2;, a3, a4			;if recording the piano to save to file, uncomment ', a3, a4'
							outs gaMasterL, gaMasterR						;the above line of code saves to file, this line sends to speakers
							
endin																			;end the instructions for instrument 4

</CsInstruments>
<CsScore>

f1 0 12 -2 8 11 13 16 18 21 24 26 29 31 34 36 			;31-Edo Pitch Table (number of half steps from A in 31edo starting with C)
f2 0 1024 5 0.01 1024 1										;Exp Curve for volume functions
f3 0 1024 5 0.001 1024 5									;Exp Curve for grain frequency functions
f4 0 4096 5 0.1 4096 2										;Exp Curve for grain length functions
f5 0 4096 5 8 3036 1 1012 1								;Exp curve for the frequency amp modifier

i1 0 3600														;turn on the tape machine
i4 0 3600														;turn on the master channel strip

</CsScore>
</CsoundSynthesizer>


<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>0</x>
 <y>0</y>
 <width>0</width>
 <height>0</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="background">
  <r>240</r>
  <g>240</g>
  <b>240</b>
 </bgcolor>
</bsbPanel>
<bsbPresets>
</bsbPresets>
