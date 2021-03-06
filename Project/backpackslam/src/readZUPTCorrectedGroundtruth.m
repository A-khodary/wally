%--------------------------------------------------------------------------
% readZUPTCorrectedGroundtruth
% coded by George Chen
%
% Parses Vasiliy's ZUPT-corrected Applanix ground truth data.
%
% This function is used by the main localization function
% ("localization.m").
%
% Input:
% - Applanix data for a ZUPT-corrected groundtruth file
%   (position is in UTM)
% Outputs:
% - truthPoses: [x; y; z; roll; pitch; yaw] all in world coordinates
%               including orientation!
% - position: [x; y; z] in world coordinates
% - orientation: orientation in Applanix coordinates, NOT world coordinates

function [truthPoses, position, orientation, timeStamps] = ...
    readZUPTCorrectedGroundtruth(applanixData)

position    = applanixData.group1.position;
orientation = applanixData.group1.attitude(:, 1:3);
timeStamps  = applanixData.group1.time(:, 3);
numReadings = length(timeStamps);
truthPoses  = [position'; zeros(3, numReadings)];

R_intermediateToWorld = rpy2rot(180, 0, 90, 'd');

for i = 1:numReadings
    R_imuToIntermediate = rpy2rot(orientation(i, 1:3)', 'd');
    truthPoses(4:6, i)  = ...
        decomposeRotationMatrix(R_intermediateToWorld * ...
                                R_imuToIntermediate);
end

end