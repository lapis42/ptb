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
paramsField = {'animalName', ...
                'time', ...
                'nDirection', ...
                'nBlock', ...
                'nTrialPerBlock', ...
                'stimulusDuration', ...
                'itiStart', ...
                'itiMean', ...
                'itiEnd', ...
                'viewAngle', ...
                'spatialFrequency', ...
                'temporalFrequency', ...
                'laserLatency'};
paramsDefault = {'test', ... % animal name
                  strftime('%Y%m%d_%H%M%S', localtime(time())), ... % time
                  12, ... % n direction
                  4, ... % n block
                  5, ... % n trial per block
                  0.5, ... % stimulus duration in second
                  0.3, ... % iti start in second
                  1, ... % iti mean in second
                  3, ... % iti end in second
                  90, ... % view angle
                  0.05, ... % spatial frequency
                  2, ... % temporal frequency
                  0}; % laser latency in ms
                 
                 
paramsValue = inputdlg(paramsField, '', 1, paramsDefault);

if isempty(paramsValue); return; end

for iParams = 3:length(paramsValue)
    paramsValue{iParams} = str2double(paramsValue{iParams});
end
params = cell2struct(paramsValue, paramsField);
params.nTrial = params.nDirection * params.nTrialPerBlock * params.nBlock;




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
grey = white / 2;


% Open window
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey);


% Make this top priority
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

% Set the blend function for the screen (I don't know what it means...)
%Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');


% Get window information 
[params.screenXpixels, params.screenYpixels] = Screen('WindowSize', window);
halfDiag = round(sqrt(params.screenXpixels ^ 2 + params.screenYpixels ^ 2) / 2);
fullDiag = halfDiag * 2 + 1;

params.ifi = Screen('GetFlipInterval', window); % inter-flip interval
params.frameRate = 1 / params.ifi;
params.stimulusFrame = round(params.stimulusDuration * params.frameRate);

% Open shader (I don't know what it means...)
AssertGLSL;
glsl = MakeTextureDrawShader(window, 'SeparateAlphaChannel');


% Keyboard information
startKey = KbName('F12');
escapeKey = KbName('SCROLLLOCK');




%% Make stimuli
% Square
squareRect = [params.screenXpixels-75, params.screenYpixels-75, params.screenXpixels, params.screenYpixels];


% Grating stimuli
gratingRect = [0, 0, fullDiag, fullDiag]; % grating size
fp = params.spatialFrequency * params.viewAngle / params.screenXpixels; % spatial frequency per pixel
p  = 1 / fp; % number of pixels for one period
fr = fp * 2 * pi; % spatial radian per pixel
x = meshgrid(-halfDiag:halfDiag + ceil(p), -halfDiag:halfDiag);
grating = 0.5 + 0.5 * cos(fr * x); % sine wave grating
grating(:, :, 2) = 0; % secondary mask for temporal shifting
grating(1:fullDiag, 1:fullDiag, 2) = 1;
gratingTex = Screen('MakeTexture', window, grating, [], [], [], [], glsl);
angle = 360 / params.nDirection;
directionBase = repmat((0:11)' * angle, params.nTrialPerBlock, 1);


%% Plot
% Initialize window
Screen('FillRect', window, black, squareRect);
Screen('TextSize', window, 40);
DrawFormattedText(window, 'Press F12 to start, and SCROLLLOCK to exit', 'center', params.screenYpixels * 0.975, [0.25, 0.25, 0.25]);
Screen('Flip', window);
inExperiment = checkWaitKey(startKey, escapeKey);

while inExperiment
    % Generate stimulus
    directions = [];
    for iBlock = 1:params.nBlock
        idx = randperm(params.nDirection * params.nTrialPerBlock);
        directions = [directions; directionBase(idx)];
    end

    iti = exprnd(params.itiMean - params.itiStart, params.nTrial, 1) + params.itiStart;
    iti(iti > params.itiEnd) = params.itiEnd;
    itiFrame = round(iti / params.ifi);    


    % Save setup data
    SAVEFOLDER = '/opt/localuser/Work/ptb/data/';
    fileName = [params.animalName, '_', strftime('%Y%m%d_%H%M%S', localtime(time())), '.mat'];
    fullFileName = fullfile(SAVEFOLDER, fileName);
    save('-mat7-binary', fullFileName, 'directions', 'itiFrame', 'params');
    

    % Initial iti
    Screen('FillRect', window, black, squareRect);
    srl_write(ser, '0');
    vbl = Screen('Flip', window);


    % Start trial
    vbl = Screen('Flip', window, vbl + 2);
    for iTrial = 1:params.nTrial
        % Trial
        %srl_write(ser, '1');
        for iFrame = 1:params.stimulusFrame
            yoffset = mod(iFrame * params.temporalFrequency * p * params.ifi, p);

            Screen('DrawTexture', window, gratingTex, gratingRect, [], directions(iTrial), [], [], [], [], [], [0, yoffset, 0, 0]);
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
        %srl_write(ser, '0');
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




