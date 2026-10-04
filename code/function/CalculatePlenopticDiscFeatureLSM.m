function Omiga  = CalculatePlenopticDiscFeatureLSM(allPts_perCorner,GridCoords )
    GridCoordsX     = GridCoords(:,:,1);
    GridCoordsY     = GridCoords(:,:,2);
    pixels          = allPts_perCorner(:,1:2);
    LensID          = allPts_perCorner(:,3);
    MicroImgCenterX = GridCoordsX(LensID);
    MicroImgCenterY = GridCoordsY(LensID);
    data_x          = [repmat([-1,0],numel(MicroImgCenterX),1),(MicroImgCenterX-pixels(:,1)),MicroImgCenterX];  % -1  0
    data_y          = [repmat([0,-1],numel(MicroImgCenterY),1),(MicroImgCenterY-pixels(:,2)),MicroImgCenterY];  %  0 -1
    window_data     = [data_x;data_y];
    [~,~,V]         = svd(window_data);
    v               = V(:,end);
    v               = v/v(end);
    w               = v(1:2)';
    R               = v(3);
    Omiga           = [w,R];
end

% function Omiga = CalculatePlenopticDiscFeatureLSM(allPts_perCorner, GridCoords)
%     % allPts_perCorner: [u v LensID]
%     % GridCoords: H×W×2, 第3维(:,:,1)=X, (:,:,2)=Y
% 
%     % 取微透镜中心坐标并强制列向量
%     GridCoordsX = GridCoords(:,:,1);
%     GridCoordsY = GridCoords(:,:,2);
%     cx = GridCoordsX(:);
%     cy = GridCoordsY(:);
% 
%     pixels = allPts_perCorner(:,1:2);
%     LensID = allPts_perCorner(:,3);
% 
%     % 基于线性索引取中心，并强制列向量
%     MicroImgCenterX = cx(LensID);  MicroImgCenterX = MicroImgCenterX(:);
%     MicroImgCenterY = cy(LensID);  MicroImgCenterY = MicroImgCenterY(:);
% 
%     px = pixels(:,1);  px = px(:);
%     py = pixels(:,2);  py = py(:);
% 
%     % 组装 LSM 矩阵（全部列向量，避免隐式扩展）
%     N = numel(LensID);
%     data_x      = [repmat([-1, 0], N, 1), (MicroImgCenterX - px), MicroImgCenterX];
%     data_y      = [repmat([ 0,-1], N, 1), (MicroImgCenterY - py), MicroImgCenterY];
%     window_data = [data_x; data_y];
% 
%     % 求解 (最小二乘) 特征参数
%     [~,~,V] = svd(window_data, 'econ');
%     v = V(:,end);
%     v = v / v(end);
% 
%     w = v(1:2).';   % 行向量 [w1 w2]
%     R = v(3);
%     Omiga = [w, R];
% end
