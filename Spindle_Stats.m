function Output = Spindle_Stats(EEGValues,EEGTimes,Fs,MinLength)
% Output = Spindle_Stats(EEGValues,EEGTimes,Fs,MinLength)
%
% Script that takes an EEG signal and calculates several sleep spindle
% related numbers.
%
% Dependencies:
% SpindleFilter.m            Filters EEG to spindle frequency
% Logical_Consecutive.m      Determines the length of sleep spindles
% Matlab Signal Processing Toolbox
% Last tested using Matlab 2020a
%
% Inputs:
% EEGValues     1xn Vector      The value of the EEG waveform
% EEGTimes      1xn vector      The time of each EEG datapoint
% Fs            Number          The sampling rate of the EEG waveform
% MinLength     Number          The minimum length for a sleep spindle
%                                  in seconds
% 
% Outputs:
% Output          A structure with the following fields:
% .Values         The filtered EEG waveform
% .Times          The Times of the filtered EEG waveform
% .Amplitude      The amplitude of the resulting waveform
% .Phase          The phase of the resulting waveform
% .Threshold      The threshold used on the Amplitude to determine a 
%                    sleep spindle.
% .SpindleLogical A logical that reports whether each data point is during
%                    a sleep spindle
% .SpindleIndex   The same as SpindleLogical, except instead of all
%                    spindles being 1, they are an integer of what number
%                    sleep spindle it is. Helps for indexing particular
%                    sleep spindles.
% 
% Given K sleep spindles detected
% 
% .SB.StartTime   1xK vector   The start time of the sleep spindle.
% .SB.EndTime     1xK vector   The end time of the sleep spindle.
% .SB.Duration    1xK vector   The duration of the sleep spindle.
% .SB.Amp         1xK cell     The amplitude of the sleep spindle at each
%                                 datapoint.
% .SB.Phase       1xK cell     The phase of the sleep spindle at each
%                                 datapoint.
% .SB.mAmp        1xK vector   The median amplitude of the sleep spindle.
% .SB.sumPhase    1xK vector   The sum of all phase changes for the spindle
%                                 burst.
% .SB.nCycles     1xK vector   The number of cycles for each sleep spindle.
%
% Last updated 6/15/2021 by Jimmy Dooley (james-c-dooley@uiowa.edu)
%
% CC-by-4.0 to Jimmy Dooley
% Used in Sokoloff et al., 2021.
%
% Cite as:
% Sokoloff G, Dooley JC, Glanz RM, Yen RY, Hickerson MM, Evans L, Laughlin
%    HM, Apfelbaum KS, and Blumberg MS (2021). Twitches emerge postnatally 
%    during quiet sleep in human infants and are synchronized with sleep 
%    spindles. Current Biology. https://doi.org/10.1016/j.cub.2021.05.038



[fValues,fTimes] = SpindleFilter(EEGValues,EEGTimes,Fs); % Filter the signal
fValuesAmp = abs(hilbert(fValues)); % Amplitude
fValuesPhase = angle(hilbert(fValues)); % Phase
dPhase = diff(unwrap(fValuesPhase)); % difference in phase
dPhase = [0; dPhase]; % Pad the vector

medAmp = nanmedian(fValuesAmp);
Threshold = medAmp*2; % Change to change threshold

fValuesAmpLogical = fValuesAmp > Threshold;
ThreshDuration = Logical_Consecutive(fValuesAmpLogical);
MinDuration = round(Fs*MinLength);


DurationLogical = ThreshDuration.ConsecutiveOutput < MinDuration;
fValuesAmpLogical(DurationLogical & fValuesAmpLogical) = 0;



ThreshDuration = Logical_Consecutive(fValuesAmpLogical);
DurationLogical = ThreshDuration.ConsecutiveOutput < MinDuration;
fValuesAmpLogical(DurationLogical & ~fValuesAmpLogical) = 1;

ThreshDuration = Logical_Consecutive(fValuesAmpLogical);

Output.Values = fValues;
Output.Times = fTimes;
Output.Amplitude = fValuesAmp;
Output.Phase = fValuesPhase;
Output.Threshold = Threshold;
Output.SpindleLogical = fValuesAmpLogical;
Output.SpindleIndex = zeros(size(fValuesAmpLogical));

dfValuesAmpLogical = diff(fValuesAmpLogical);
SSI = find(dfValuesAmpLogical == 1); % Spindle Start Index
SEI = find(dfValuesAmpLogical == -1); % Spindle End Index

if SEI(1) < SSI(1) % If you start in the middle of a sleep spindle
    SEI = SEI(2:end);
end
if SEI(end) < SSI(end) % If you end on a sleep spindle
    SSI = SSI(1:end-1);
end

nSpindles = min([length(SEI); length(SSI)]);

for iSpindle = 1:nSpindles
    Output.SpindleIndex(SSI(iSpindle):SEI(iSpindle)) = iSpindle; % Create string for easy sleep spindle indexing
    Output.SB.StartTime(iSpindle) = SSI(iSpindle)/Fs; % Get sleep spindle start time (in seconds)
    Output.SB.EndTime(iSpindle) = SEI(iSpindle)/Fs; % Get sleep spindle end time (in seconds)
    Output.SB.Duration(iSpindle) = Output.SB.EndTime(iSpindle) - Output.SB.StartTime(iSpindle); % Get sleep spindle duration
    Output.SB.Amp{iSpindle} = fValuesAmp(SSI(iSpindle):SEI(iSpindle)); % Get sleep spindle amplitude throughout 
    Output.SB.Phase{iSpindle} = fValuesPhase(SSI(iSpindle):SEI(iSpindle)); % Get sleep spindle phase throughout
    Output.SB.mAmp(iSpindle) = median(fValuesAmp(SSI(iSpindle):SEI(iSpindle))); % Get sleep spindle median amplitude
    Output.SB.sumPhase(iSpindle) = sum(dPhase(SSI(iSpindle):SEI(iSpindle))); % Get the phase duration of the sleep spindle
    Output.SB.nCycles(iSpindle) = Output.SB.sumPhase(iSpindle) / (2*pi); % Get the number of cycles of the sleep spindle
end
