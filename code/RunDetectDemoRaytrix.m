clear
DataPath                          = 'E:\MATLAB\project\SHENJIANJIE\data\L5\L5_gaijin';
% FilePath_White                    = 'E:\MATLAB\project\SHENJIANJIE\data\L3\XML'; 
FilePath_White                    = 'E:\MATLAB\project\SHENJIANJIE\data\L5\L5_truth\processed_White.mat'; 
DefaultFileSpec_Raw               = {'*.png'};
ConfigBag.neighbrs                = 32;     % ROI range 
ConfigBag.SearchThreshold         = 5;      % remove corenrs located on the edges of micro-images
ConfigBag.Error_Inner             = 1.5;    % the 
ConfigBag.ProjTresh               = 2;      % remove project points  on the edges of microimage.
ConfigBag.delta                   = 0.5;%1;      % Gaussian filter delta.
ConfigBag.Optdelta                = 0.3;
ConfigBag.FilterRadius            = [2,4];
ConfigBag.OptThresh               = 5;
ShowFlag                          = true;
pixelX                            = 6000;
pixelY                            = 4000;
InfoBag.FlagRemoveEdge            = true;
ConfigBag.CameraType              = 'Raytrix';


% load the information about MLA.
% [LensletGridModel, GridCoords] = FuncGenerateMLA([pixelY,pixelX], FilePath_White ,ShowFlag,InfoBag);

[LensletGridModel, GridCoords, LensClass] = Generate(FilePath_White);
save([DataPath,'\lensmodel'],'LensletGridModel', 'GridCoords');

% Detect corners.
ConfigBag.FilePath_Raw            = DataPath;
ConfigBag.DefaultFileSpec_Raw     = DefaultFileSpec_Raw ;
[allPts,allClearPts,allOmega ]    = DetectCornersOurs(GridCoords,LensletGridModel,LensClass,ConfigBag);

% Save the results.
save([DataPath,'/OurNewDetectResults'], 'allPts','allClearPts','allOmega');

% Show the detect results.
load([DataPath,'/OurNewDetectResults'], 'allPts','allClearPts');
% ShowDetectResults(DataPath, DefaultFileSpec_Raw,allClearPts);

