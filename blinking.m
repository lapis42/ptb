function basic_stim_serial()
%% Installation instruction for Psychtoolbox
% bash
%   sudo apt-get install octave
%   sudo apt-get install liboctave-dev
%   sudo apt-get install octave-psychtoolbox-3
%   sudo octave --no-gui

%% Installing instrument crontol package
% octave
%   pkg install -forge instrument-control
%   pkg load instrument-control

sca;
close all;
clear;




%% Experimental parameters
SAVEFOLDER = '/mnt/data/ptb/';

paramsField = {'animalName', ...
               'time', ...
               'nTrial', ...
               'stimulusDuration', ...
               'itiStart', ...
               'itiMean', ...
               'itiEnd', ...
               'laserLatency'};
paramsDefault = {'ptb', ... % animal name
                  strftime('%Y%m%d_%H%M%S', localtime(time())), ... % time
                  120, ... % n trial per block
                  0.5, ... % stimulus duration in second
                  0.5, ... % iti start in second
                  1.5, ... % iti mean in second
                  3, ... % iti end in second
                  0}; % laser latency in ms
                 
                 
paramsValue = inputdlg(paramsField, '', 1, paramsDefault);

if isempty(paramsValue); return; end

for iParams = 3:length(paramsValue)
    paramsValue{iParams} = str2double(paramsValue{iParams});
end
params = cell2struct(paramsValue, paramsField);



%% Serial commnunication
pkg load instrument-control
ser = serial('/dev/ttyACM0');
srl_write(ser, '0');
pause(0.05);
srl_write(ser, ['l', params.laserLatency]);



%% Psychtoolbox setup
% Change preference
PsychDefaultSetup(2);
Screen('Preference', 'VisualDebuglevel', 3);
oldEnableFlag = Screen('Preference', 'Verbosity', [1]);
oldSyncFlag = Screen('Preference', 'SkipSyncTests', 2);


% Get screen information
screens = Screen('Screens');
screenNumber = max(screens);
white = WhiteIndex(screenNumber);
black = BlackIndex(screenNumber);


% Open window
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, black);


% Make this top priority
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

% Set the blend function for the screen (I don't know what it means...)
%Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');


% Get window information 
[params.screenXpixels, params.screenYpixels] = Screen('WindowSize', window);

params.ifi = Screen('GetFlipInterval', window); % inter-flip interval
params.frameRate = 1 / params.ifi;
params.stimulusFrame = round(params.stimulusDuration * params.frameRate);
durationTotal = params.nTrial * (params.stimulusDuration + params.itiMean);
fprintf('\nDuration: %d\n', durationTotal / 60);


% Open shader (I don't know what it means...)
AssertGLSL;
glsl = MakeTextureDrawShader(window, 'SeparateAlphaChannel');


% Keyboard information
startKey = KbName('F12');
escapeKey = KbName('SCROLLLOCK');




%% Make stimuli
% Square
squareRect = [0, 0, params.screenXpixels, params.screenYpixels];


%% Plot
% Initialize window
Screen('FillRect', window, black, squareRect);
Screen('TextSize', window, 40);
DrawFormattedText(window, 'Press F12 to start, and SCROLLLOCK to exit', 'center', params.screenYpixels * 0.975, [0.25, 0.25, 0.25]);
Screen('Flip', window);
inExperiment = checkWaitKey(startKey, escapeKey);

while inExperiment
    iti = exprnd(params.itiMean - params.itiStart, params.nTrial, 1) + params.itiStart;
    iti(iti > params.itiEnd) = params.itiEnd;
    itiFrame = round(iti / params.ifi);    


    % Save setup data
    fileName = [params.animalName, '_', strftime('%Y%m%d_%H%M%S', localtime(time())), '.mat'];
    fullFileName = fullfile(SAVEFOLDER, fileName);
    

    % Initial iti
    Screen('FillRect', window, black, squareRect);
    srl_write(ser, '0');
    vbl = Screen('Flip', window);


    % Start trial
    vbl = Screen('Flip', window, vbl + 2);
    for iTrial = 1:params.nTrial
        % Trial
        for iFrame = 1:params.stimulusFrame
            Screen('FillRect', window, white, squareRect);

            if checkKey(escapeKey)
                srl_write(ser, '0');
                directions = directions(1:(iTrial-1));
                itiFrame = itiFrame(1:(iTrial-1));
                save('-mat7-binary', fullFileName, 'directions', 'itiFrame', 'params');
                finishTask();
                return
            end

            if iFrame == 3
                srl_write(ser, '1');
            end

            vbl = Screen('Flip', window, vbl + 0.5 * params.ifi);
        end

        % Inter-trial interval
        for iFrame = 1:itiFrame(iTrial)
            Screen('FillRect', window, black, squareRect);

            if checkKey(escapeKey)
                srl_write(ser, '0');
                directions = directions(1:(iTrial-1));
                itiFrame = itiFrame(1:(iTrial-1));
                save('-mat7-binary', fullFileName, 'directions', 'itiFrame', 'params');
                finishTask();
                return
            end

            if iFrame == 3
                srl_write(ser, '0');
            end
           
            vbl = Screen('Flip', window, vbl + 0.5 * params.ifi);
        end
    end

    save('-mat7-binary', fullFileName, 'directions', 'itiFrame', 'params');
    Screen('FillRect', window, black, squareRect);
    DrawFormattedText(window, 'Press F12 to start, and SCROLLLOCK to exit', 'center', params.screenYpixels * 0.975, [0.25, 0.25, 0.25]);
    Screen('Flip', window);
    inExperiment = checkWaitKey(startKey, escapeKey);
end
srl_write(ser, '0');
finishTask();
fclose(ser);



function inExperiment = checkWaitKey(startKey, escapeKey)
notDone = true;
while notDone
    [~, keyCode] = KbStrokeWait;

    if keyCode(escapeKey)
        inExperiment = false;
        notDone = false;
    elseif keyCode(startKey)
        inExperiment = true;
        notDone = false;
    end
end



function stop = checkKey(escapeKey)
[keyDown, ~, keyCode] = KbCheck;
stop = false;
if keyCode(escapeKey)
    stop = true;
end



function finishTask()
% Clear the screen
Priority(0);
sca;




