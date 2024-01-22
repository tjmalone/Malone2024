%% listener_fAcq
% Listener reports actions taking place within ScanImage to the command
% line. listener_fAcq records an acquision taking place. To create
% listener, call with inputs frNum and channel. To activate listener, set
% frCount to 0. This is followed by creating new figure and using uiwait.
% This figure should then be closed and cleared. frMean and frMax can then
% be extracted. Listener can be reset by resetting frCount to 0. When
% finished, delete and clear the listener. See zGrab for example of proper
% use. 
%

classdef listener_fAcq < handle
    
    properties
        hSI                         % The scanimage API
        listeners = {}              % scanimage listener object
        frNum = []                  % number of frames to record
        channel = []                % recording channel
        frCount = -1                % number of frames taken (-1 = off)
        frArray = []                % storage array for recorded frames
        frMean = []                 % mean fluorescence of recorded frames
        frMax = []                  % max fluorescence of recorded frames
    end
    
    methods
        
        function obj = listener_fAcq(frNum,channel)           
            % get hSI from the base workspace
            obj.hSI = evalin('base','hSI');
            
            % Add listener triggered when frame is acquired
            obj.listeners{1} = addlistener...
                (obj.hSI.hUserFunctions,'frameAcquired',@obj.fAcq);
            
            % initialize parameters
            obj.frNum = frNum;
            obj.channel = channel;
        end
        
        
        function delete(obj)
            % Detach from the listeners
            cellfun(@delete,obj.listeners)
        end
        
        
        function fAcq(obj,~,~)
            if obj.frCount>=1
                % get pointer to last aquired stripeData
                lastStripe = obj.hSI.hDisplay.stripeDataBuffer...
                    {obj.hSI.hDisplay.stripeDataBufferPointer};
                
                % extract channel of interest
                fr = lastStripe.roiData{1}.imageData{obj.channel}{1};
                
                % record current frame
                obj.frArray(:,:,obj.frCount) = fr;
                
                % when all frames completed
                if obj.frCount==obj.frNum
                    obj.frMean = mean(obj.frArray,3);   % calculate mean
                    obj.frMax = max(obj.frArray,[],3);  % calculate max
                    obj.frArray = [];                   % clear array
                    obj.frCount = -1;                   % turn off listener
                    uiresume                            % resume function
                else
                    % increment frame count
                    obj.frCount = obj.frCount+1;
                end
            elseif obj.frCount==0       % buffer to prevent partial frame
                obj.frCount = 1;
            end
        end

    end
    
end