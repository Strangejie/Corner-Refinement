% function [Omega,ClearType,ClearPts_perCorner] = OptimizeCorner(corners,CellRGBLensID,Img_raw2,Img_raw,GridCoords,LensRadius,ConfigBag,templateCell,CornerType,Debug)
% 
%     ClearType = 0;
%     if isfield(ConfigBag,'CameraType')
%         CameraType = ConfigBag.CameraType;
%     else
%         ConfigBag.CameraType = 'Raytrix';
%         CameraType = 'Raytrix';
%     end
%     
%     allPts_perCorner            = [corners.pImg,  corners.LensID];
%     if Debug == true
%         figure;imshow(Img_raw2);hold on; plot(corners.pImg(:,1),corners.pImg(:,2),'*');hold off;
%     end
%     
%     % calculate Plenoptic disc features roughly.
%     Omega                   = CalculatePlenopticDiscFeatureLSM(allPts_perCorner,GridCoords );      
%     
%     % form new ROI 
%     allProjPtsPerCorner      = ProjectPDF2Img(Omega, GridCoords, LensRadius,-1 ,0); % 这个需要后期测试。
%     if  isempty(allProjPtsPerCorner)
%         Omega     = [];
%         ClearType = 0;
%         ClearPts_perCorner =[];
%         return;
%     end
%     GridCoordsX              = GridCoords(:,:,1);
%     GridCoordsY              = GridCoords(:,:,2);
%     NbLensCoords             = [ GridCoordsX(allProjPtsPerCorner(:,3)) , GridCoordsY(allProjPtsPerCorner(:,3)) ];
%     [RawROI,ROILeftCoords]   = FormROIImg(Img_raw, NbLensCoords,   LensRadius); 
%     
%     % Detect corners within new ROI.
%     %templateCell             = templateCell(CornerType);
%     [corners1,corners2]      = findCorners(RawROI,templateCell,0.025);
%     if CornerType==1
%         corners = corners1;
%     else
%         corners = corners2;
%     end
%     
%     % remove corner
%     if  Debug ==true
%         figure;imshow(RawROI);hold on; plot(corners.p(:,1),corners.p(:,2),'*');hold off;
%     end
%     
%     corners                     = RemoveCornersOnEdge(ROILeftCoords,corners, NbLensCoords,LensRadius,ConfigBag.SearchThreshold ,allProjPtsPerCorner(:,3));
%     [corners,ImgBag]            = CalculateCornerOrientationAndFocusScore(RawROI,corners);
%     
%     if  Debug ==true
%         figure;imshow(RawROI);hold on; plot(corners.p(:,1),corners.p(:,2),'*');hold off;
%     end
% 
% %     if strcmp(CameraType,'Raytrix')
% %         % corner refine  
% %         cornersRefine               = RefineSelectedCorners(corners,ImgBag,GridCoords,LensRadius);         % refine radius is better to be adjusted
% %         cornersRefine               = RemoveCornerwithLowQuality(cornersRefine,0.003);
% %         if  Debug ==true
% %             figure;imshow(RawROI);hold on; plot(cornersRefine.p(:,1),cornersRefine.p(:,2),'*');hold off;
% %         end       
% %     else
%         points             = RefineCornerSmallPatch(RawROI,CornerType, corners.p);
%         offset             = points - corners.p;
%         corners.pImg       = corners.pImg+offset;
%         corners.p          = points;
%         cornersRefine      = corners;
%     %end
% 
%     % choose the corners which is close to project poinst.
%     allPts_perCorner = [];
%     IDList           = [];
%     cornerNum        = size(cornersRefine.pImg,1);
%     for id = 1 :cornerNum
%        CurCornerCoords  = cornersRefine.pImg(id,:); % 
%        CurLensID        = cornersRefine.LensID(id); % the refined corner's lens index.
%        findFlag         = sum((allProjPtsPerCorner(:,3)==CurLensID));  
%        if  findFlag==1 % if a detected point and a projected point are in the same lens.
%            ProjCornerCoords = allProjPtsPerCorner( (allProjPtsPerCorner(:,3)==CurLensID) , 1:2);
%            dist             = sqrt( sum( ( CurCornerCoords - ProjCornerCoords ).^2,2) );  %%the code here should be changed
%            if dist < 2
%                IDList            = [IDList;id];
%                allPts_perCorner  = [allPts_perCorner;[CurCornerCoords,  cornersRefine.LensID(id)]];
%            end
%        end
%     end        
%     
%     % make sure that there is more than 2 corners left.
%     CornerNumLeft = size(IDList,1);
%     if CornerNumLeft < 2
%         Omega     = [];
%         ClearType = 0;
%         ClearPts_perCorner =[];
%         return;
%     end
%     
%     cornersInner = UpdateCorner(cornersRefine,IDList);     
%     if Debug == true
%         figure;imshow(Img_raw2);hold on; plot(allPts_perCorner(:,1),allPts_perCorner(:,2),'*');hold off;
%     end
%     
%     if strcmp(CameraType,'Raytrix')
%         % Classify the  corners types through corner focus scores.
%         [allPts_perCorner,ClearPts_perCorner,ClearType] = SelectClearPoints(cornersInner.FocusScore, allPts_perCorner, CellRGBLensID);
%         if Debug == true
%             figure;imshow(Img_raw2);hold on; plot(ClearPts_perCorner(:,1),ClearPts_perCorner(:,2),'*');hold off;
%         end
%         if size(allPts_perCorner,1)<=1
%             ClearType = 0;
%             return;
%         end    
%         % Optimize the plenoptic disc radius by simularity.
%         ClearNum                    = size(ClearPts_perCorner,1);  % 这里应该根据omega的半径判断。是否使用清晰点进行优化。
%         if ClearNum >= 2            % if there are enough clear corners.
%             Omega                   = CalculatePlenopticDiscFeatureLSM(ClearPts_perCorner,GridCoords );
%             PDRadiusOpt             = OptimizePlenopticDiscRadius(Img_raw2, Omega, GridCoords,LensRadius,CellRGBLensID{ClearType},ConfigBag.OptThresh);
%         else
%             Omega                   = CalculatePlenopticDiscFeatureLSM(ClearPts_perCorner,GridCoords );
%             PDRadiusOpt             = OptimizePlenopticDiscRadius(Img_raw2, Omega, GridCoords,LensRadius,-1,ConfigBag.OptThresh);
%         end                         % ShowPDF(Img_raw,Omiga,LensRadius);
%         if  abs(  abs(PDRadiusOpt) - abs(Omega(3)) ) < 3     % make sure the optimization is within the possible range.
%             Omega(3) = PDRadiusOpt;
%         end
%     end
%     
%     if strcmp(CameraType,'Lytro')
%         ClearType = 0;
%         Omega                   = CalculatePlenopticDiscFeatureLSM(allPts_perCorner,GridCoords );
%         PDRadiusOpt             = OptimizePlenopticDiscRadius(Img_raw2, Omega, GridCoords,LensRadius,-1,ConfigBag.OptThresh);
%         ClearPts_perCorner      = allPts_perCorner;
%         if  abs(  abs(PDRadiusOpt) - abs(Omega(3)) ) < 3     % make sure the optimization is within the possible range.
%             Omega(3) = PDRadiusOpt;
%         end
%     end
%     
% end
% 
% 
% 
% 
% 
% function  points = RefineCornerSmallPatch(Ig,CornerType, pointsInterger)
%     derivFilter = [-1 0 1];
%     Iy = imfilter(Ig, derivFilter', 'conv');  % y方向一阶偏导
%     Ix = imfilter(Ig, derivFilter, 'conv');   % x方向一阶偏导
%     if CornerType ==1
%         % second derivative
%         Ixy = imfilter(Ix, derivFilter', 'conv');    % 二阶偏导IxIy
%         IXY = Ixy;
%     else
%         % define steerable filter constants
%         cosPi4 = coder.const(cast(cos(pi/4), 'like', Ig));      % cospi/4
%         cosNegPi4 = coder.const(cast(cos(-pi/4), 'like', Ig));  % cos(-pi/4)
%         sinPi4 = coder.const(cast(sin(pi/4), 'like', Ig));      % sin(pi/4)
%         sinNegPi4 = coder.const(cast(sin(-pi/4), 'like', Ig));  % sin(-pi/4)
%         % first derivative at 45 degrees
%         I_45 = Ix * cosPi4 + Iy * sinPi4;             % 45度方向 1阶偏导
%         I_45_x = imfilter(I_45, derivFilter, 'conv'); % 2阶偏导 I45Ix
%         I_45_y = imfilter(I_45, derivFilter', 'conv');  % 2阶偏导  I45Iy
%         I_45_45 = I_45_x * cosNegPi4 + I_45_y * sinNegPi4;  % 2阶偏导 I45In45
%         IXY =I_45_45;
%     end
%     points              = vision.internal.calibration.checkerboard.subPixelLocation(IXY, pointsInterger);
% end


%% 新增选择，清晰角点或用全部角点
function [Omega,ClearType,ClearPts_perCorner] = OptimizeCorner(corners, CellRGBLensID, Img_raw2, Img_raw, GridCoords, LensRadius, ConfigBag, templateCell, CornerType, Debug)
% 作用：
%  1) 以 RANSAC 后留下的 corners 为初集，粗估 Omega；
%  2) 用投影得到的镜组形成新 ROI，在 ROI 内重做角点检测+筛边+方向/梯度；
%  3) 小块亚像素细化；
%  4) 仅保留“与投影镜 ID 匹配且投影几何一致”的角点（allPts_perCorner）；
%  5) Raytrix 下按 FocusScore 进行清晰分类（得到 ClearPts_perCorner, ClearType）；
%  6) 根据 ConfigBag.UseOnlyClearForRaytrix 开关：
%       - true 且清晰点数≥2 : 用清晰点优化；
%       - 否则：用全部点优化；
%     => 把“用于优化的一批点”也作为 ClearPts_perCorner 输出，便于外部直接可视化。
%
% 输入：
%   corners.pImg [N×2], corners.LensID [N×1], 以及可能已有的 v1/v2/FocusScore 等
%   CellRGBLensID : {R;G;B} 三类镜的线性索引（Raytrix 用于清晰分类/相似度优化）
%   Img_raw2 : 滤波图（相似度优化用）
%   Img_raw  : 原图（形 ROI 用）
%   GridCoords, LensRadius, ConfigBag, templateCell, CornerType, Debug
%
% 输出：
%   Omega              : 最终的 PDF 参数 [ox, oy, r]
%   ClearType          : 1/2/3（Raytrix 清晰类），Lytro/未用清晰分类时为 0
%   ClearPts_perCorner : “用于优化的角点集合”（清晰或全部，取决于开关）[M×3: x y LensID]

    % ---------- 基本配置 ----------
%     UseOnlyClearForRaytrix = getfield_def(ConfigBag, 'UseOnlyClearForRaytrix', true);
%     CameraType             = getfield_def(ConfigBag, 'CameraType', 'Raytrix');

    UseOnlyClearForRaytrix = ConfigBag.UseOnlyClearForRaytrix;
    CameraType             = ConfigBag.CameraType;

    % ---------- 初集可视化 ----------
    allPts_perCorner = [corners.pImg, corners.LensID];
    if Debug
        figure; imshow(Img_raw2,[]); hold on;
        plot(allPts_perCorner(:,1), allPts_perCorner(:,2), 'y*');
        title('RANSAC后初角点（全图坐标）'); hold off;
    end

    % ---------- 1) 粗估 Omega ----------
    Omega = CalculatePlenopticDiscFeatureLSM(allPts_perCorner, GridCoords);

    % ---------- 2) 新 ROI：基于当前 Omega 投影到镜阵 ----------
    allProjPtsPerCorner = ProjectPDF2Img(Omega, GridCoords, LensRadius, -1, 0);
    if isempty(allProjPtsPerCorner)
        Omega = []; ClearType = 0; ClearPts_perCorner = [];
        return;
    end

    % 形 ROI（包含所有被投影命中的镜的中心）
    GX = GridCoords(:,:,1); GY = GridCoords(:,:,2);
    NbLensCoords           = [ GX(allProjPtsPerCorner(:,3)), GY(allProjPtsPerCorner(:,3)) ];
    [RawROI, ROILeftCoords]= FormROIImg(Img_raw, NbLensCoords, LensRadius);

    % ---------- 3) ROI 内重新角点检测 ----------
    % 注意：为了兼容 CornerType=1/2，仍用两类模板，一会儿再按 CornerType 取其一
    [c1, c2] = findCorners(RawROI, templateCell, 0.025);
    if CornerType == 1, cornersROI = c1; else, cornersROI = c2; end

    if Debug
        figure; imshow(RawROI,[]); hold on;
        if ~isempty(cornersROI.p), plot(cornersROI.p(:,1), cornersROI.p(:,2), 'c+'); end
        title('新 ROI 内检测到的角点（ROI坐标）'); hold off;
    end

    % ---------- 4) ROI->全图 & 剔边 & 方向/梯度 ----------
    cornersROI = RemoveCornersOnEdge(ROILeftCoords, cornersROI, ...
                    NbLensCoords, LensRadius, ConfigBag.SearchThreshold, allProjPtsPerCorner(:,3));
    [cornersROI, ImgBag] = CalculateCornerOrientationAndFocusScore(RawROI, cornersROI);

    if Debug
        figure; imshow(RawROI,[]); hold on;
        if ~isempty(cornersROI.p), plot(cornersROI.p(:,1), cornersROI.p(:,2), 'g+'); end
        title('剔边 + 方向/梯度后（ROI坐标）'); hold off;
    end

    % ---------- 5) 小块亚像素细化 ----------
    pts_subpix  = RefineCornerSmallPatch(RawROI, CornerType, cornersROI.p);
    offset      = pts_subpix - cornersROI.p;
    cornersROI.p      = pts_subpix;
    cornersROI.pImg   = cornersROI.pImg + offset;  % 同步全图坐标
    cornersRefine     = cornersROI;

    % ---------- 6) 与投影镜ID一致 + 几何一致性 ----------
    % 只保留与 allProjPtsPerCorner 同镜 ID（且与投影几何距离<阈值）的角点
    allPts_perCorner = [];             % 重建“内点全集”
    IDList           = [];
    cornerNum        = size(cornersRefine.pImg,1);
    for id = 1:cornerNum
        CurCornerCoord = cornersRefine.pImg(id,:);
        CurLensID      = cornersRefine.LensID(id);
        if any(allProjPtsPerCorner(:,3) == CurLensID)
            ProjCorner = allProjPtsPerCorner(allProjPtsPerCorner(:,3) == CurLensID, 1:2);
            dist       = hypot(CurCornerCoord(1)-ProjCorner(1), CurCornerCoord(2)-ProjCorner(2));
            if dist < 2    % 投影一致性阈值，可适当放宽到 2~3
                IDList          = [IDList; id];
                allPts_perCorner= [allPts_perCorner; [CurCornerCoord, CurLensID]];
            end
        end
    end

    if Debug
        figure; imshow(Img_raw2,[]); hold on;
        if ~isempty(allPts_perCorner), plot(allPts_perCorner(:,1), allPts_perCorner(:,2), 'm*'); end
        title('投影一致性后的内点（全图坐标）'); hold off;
    end

    % 至少要有 2 个点才能稳健估计
    if size(IDList,1) < 2
        Omega = []; ClearType = 0; ClearPts_perCorner = [];
        return;
    end

    % ---------- 7) 形成“内点”子结构（同步 v1/v2/FocusScore） ----------
    cornersInner = UpdateCorner(cornersRefine, IDList);

    % ---------- 8) Raytrix：清晰分类 & 决定优化点集 ----------
    if strcmpi(CameraType, 'Raytrix')

        % 保存“全部内点”，以备开关= false 时使用
        allPts_all = allPts_perCorner;

        % 根据 FocusScore + CellRGBLensID 做清晰分类
        [allPts_perCorner, ClearPts_perCorner, ClearType] = ...
            SelectClearPoints(cornersInner.FocusScore, allPts_perCorner, CellRGBLensID);

        if Debug
            figure; imshow(Img_raw2,[]); hold on;
            if ~isempty(ClearPts_perCorner), plot(ClearPts_perCorner(:,1), ClearPts_perCorner(:,2), 'r*'); end
            title('清晰子集（全图坐标）'); hold off;
        end

        % 选择“用于优化”的集合
        useClear = UseOnlyClearForRaytrix && (size(ClearPts_perCorner,1) >= 2);
        if useClear
            PtsForOptimize = ClearPts_perCorner;
            lensMaskForSim = CellRGBLensID{ClearType};   % 相似度优化只在该清晰类镜中
        else
            PtsForOptimize = allPts_all;
            lensMaskForSim = -1;                         % 不限清晰类
            ClearType      = 0;                          % 表示“并非只用清晰类”
        end

        if size(PtsForOptimize,1) <= 1
            Omega = []; ClearType = 0; ClearPts_perCorner = [];
            return;
        end

        % 重新估计 Omega & 优化半径
        Omega       = CalculatePlenopticDiscFeatureLSM(PtsForOptimize, GridCoords);
        PDRadiusOpt = OptimizePlenopticDiscRadius(Img_raw2, Omega, GridCoords, LensRadius, lensMaskForSim, ConfigBag.OptThresh);
        if abs(abs(PDRadiusOpt) - abs(Omega(3))) < 3
            Omega(3) = PDRadiusOpt;
        end

        % 关键：把“用于优化”的集合作为输出，方便外部可视化得到一致的结果
        ClearPts_perCorner = PtsForOptimize;

    else
        % ---------- 9) Lytro 或未做清晰分类：用全部内点 ----------
        ClearType          = 0;
        ClearPts_perCorner = allPts_perCorner;

        Omega       = CalculatePlenopticDiscFeatureLSM(ClearPts_perCorner, GridCoords);
        PDRadiusOpt = OptimizePlenopticDiscRadius(Img_raw2, Omega, GridCoords, LensRadius, -1, ConfigBag.OptThresh);
        if abs(abs(PDRadiusOpt) - abs(Omega(3))) < 3
            Omega(3) = PDRadiusOpt;
        end
    end
end


% --------- 小工具：安全读字段 ----------
% function v = getfield_def(S, name, default)
%     if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
%         v = S.(name);
%     else
%         v = default;
%     end
% end

function  points = RefineCornerSmallPatch(Ig,CornerType, pointsInterger)
    derivFilter = [-1 0 1];
    Iy = imfilter(Ig, derivFilter', 'conv');  % y方向一阶偏导
    Ix = imfilter(Ig, derivFilter, 'conv');   % x方向一阶偏导
    if CornerType ==1
        % second derivative
        Ixy = imfilter(Ix, derivFilter', 'conv');    % 二阶偏导IxIy
        IXY = Ixy;
    else
        % define steerable filter constants
        cosPi4 = coder.const(cast(cos(pi/4), 'like', Ig));      % cospi/4
        cosNegPi4 = coder.const(cast(cos(-pi/4), 'like', Ig));  % cos(-pi/4)
        sinPi4 = coder.const(cast(sin(pi/4), 'like', Ig));      % sin(pi/4)
        sinNegPi4 = coder.const(cast(sin(-pi/4), 'like', Ig));  % sin(-pi/4)
        % first derivative at 45 degrees
        I_45 = Ix * cosPi4 + Iy * sinPi4;             % 45度方向 1阶偏导
        I_45_x = imfilter(I_45, derivFilter, 'conv'); % 2阶偏导 I45Ix
        I_45_y = imfilter(I_45, derivFilter', 'conv');  % 2阶偏导  I45Iy
        I_45_45 = I_45_x * cosNegPi4 + I_45_y * sinNegPi4;  % 2阶偏导 I45In45
        IXY =I_45_45;
    end
    points              = vision.internal.calibration.checkerboard.subPixelLocation(IXY, pointsInterger);
end
