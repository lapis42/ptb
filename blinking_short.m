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
               'nBlock', ...
               'nTrialTest', ...
               'nTrialControl', ...
               'itiStart', ...
               'itiMean', ...
               'itiEnd', ...
               'laserLatency', ...
               'laserDuration', ...
               'laserEnable'};
paramsDefault = {'ptb', ... % animal name
                  strftime('%Y%m%d_%H%M%S', localtime(time())), ... % time
                  10, ... % n block
                  10, ... % n trial test per block
                  5, ... % n trial control per block
                  1.0, ... % iti start in second
                  2.0, ... % iti mean in second
                  3, ... % iti end in second
                  0, ... % laser latency in ms
                  20, ... % laser duration in ms
                  1}; % laser enable
                 
                 
paramsValue = inputdlg(paramsField, '', 1, paramsDefault);
if isempty(paramsValue); return; end

for iParams = 3:length(paramsValue)
    paramsValue{iParams} = str2double(paramsValue{iParams});
end
params = cell2struct(paramsValue, paramsField);
params.nTrial = params.nBlock * (params.nTrialTest + params.nTrialControl);



%% Serial commnunication
pkg load instrument-control
ser = serial('/dev/ttyACM0');
srl_write(ser, '0d');
pause(0.05);
srl_write(ser, ['l', params.laserLatency]); % set laser latency from FPGA output
srl_write(ser, ['D', params.laserDuration]); % set laser duration



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
itiStart = round(params.itiStart/ params.ifi);    


% Open shader (I don't know what it means...)
AssertGLSL;
glsl = MakeTextureDrawShader(window, 'SeparateAlphaChannel');


% Keyboard information
startKey = KbName('F12');
escapeKey = KbName('SCROLLLOCK');




%% Make stimuli
% Square
squareRect = [0, 0, params.screenXpixels, params.screenYpixels];
if params.laserEnable
    enableBase = [true(params.nTrialTest, 1); false(params.nTrialControl, 1)];
else
    enableBase = false(params.nTrialTest + params.nTrialControl, 1);
end


%% Plot
% Initialize window
Screen('FillRect', window, black, squareRect);
Screen('TextSize', window, 40);
DrawFormattedText(window, 'Press F12 to start, and SCROLLLOCK to exit', 'center', params.screenYpixels * 0.975, [0.25, 0.25, 0.25]);
Screen('Flip', window);
inExperiment = checkWaitKey(startKey, escapeKey);

while inExperiment
    % Generate trial structure
    enable = [];
    for iBlock = 1:params.nBlock
        idx = randperm(params.nTrialTest + params.nTrialControl);
        enable = [enable; enableBase(idx)];
    end
    iti = exprnd(params.itiMean - params.itiStart, params.nTrial, 1); % iti except params.itiStart!!!!
    iti(iti > params.itiEnd) = params.itiEnd - params.itiStart;
    itiFrame = round(iti / params.ifi);    


    % Save setup data
    fileName = [params.animalName, '_', strftime('%Y%m%d_%H%M%S', localtime(time())), '.mat'];
    fullFileName = fullfile(SAVEFOLDER, fileName);
    

    % Initial iti
    Screen('FillRect', window, black, squareRect);
    srl_write(ser, '0d');
    vbl = Screen('Flip', window);


    % Start trial
    vbl = Screen('Flip', window, vbl + 1);
    for iTrial = 1:params.nTrial
        % Pre-trial delay (duration: itiStart)
        for iFrame = 1:itiStart
            Screen('FillRect', window, black, squareRect);

            if checkKey(escapeKey)
                srl_write(ser, '0d');
                enable = enable(1:(iTrial-1));
                itiFrame = itiFrame(1:(iTrial-1));
                save('-mat7-binary', fullFileName, 'enable', 'itiFrame', 'params');
                finishTask();
                return
            end

            if iFrame == 3
                srl_write(ser, '0');
            end

            if iFrame == round(itiStart / 2)
                if enable(iTrial)
                    srl_write(ser, 'e');
                else
                    srl_write(ser, 'd');
                end
            end
           
            vbl = Screen('Flip', window, vbl + 0.5 * params.ifi);
        end

        % Trial (1 frame only)
        Screen('FillRect', window, white, squareRect);
        vbl = Screen('Flip', window, vbl + 0.5 * params.ifi);

        % Post-trial delay (duration: itiFrame)
        for iFrame = 1:itiFrame(iTrial)
            Screen('FillRect', window, black, squareRect);

            if checkKey(escapeKey)
                srl_write(ser, '0d');
                enable = enable(1:(iTrial-1));
                itiFrame = itiFrame(1:(iTrial-1));
                save('-mat7-binary', fullFileName, 'enable', 'itiFrame', 'params');
                finishTask();
                return
            end

            if iFrame == 2
                srl_write(ser, '1');
            end

            if iFrame == 3
                srl_write(ser, '0');
            end
           
            vbl = Screen('Flip', window, vbl + 0.5 * params.ifi);
        end

    end

    % Last iti
    Screen('FillRect', window, black, squareRect);
    srl_write(ser, '0d');
    vbl = Screen('Flip', window, vbl + 1);



    save('-mat7-binary', fullFileName, 'enable', 'itiFrame', 'params');
    Screen('FillRect', window, black, squareRect);
    DrawFormattedText(window, 'Press F12 to start, and SCROLLLOCK to exit', 'center', params.screenYpixels * 0.975, [0.25, 0.25, 0.25]);
    Screen('Flip', window);
    inExperiment = checkWaitKey(startKey, escapeKey);
end

srl_write(ser, '0d');
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

