% function corners = RemoveCornersOnEdge(ROILeftCoords,corners, NbLensCoords,LensRadius,SearchThreshold,CurrentLensIDnearCorner)
%     minX                    = ROILeftCoords(1);
%     minY                    = ROILeftCoords(2);
%     CornersNumROI           = size(corners.p,1);  % 角点的总数量。    
%     LensIDperCorner         = [];
%     CornerIDnoEdges         = [];
%     CornerCoordsImg         = [];
%     if CornersNumROI>0
%         CornerCoordsImg      = corners.p(:,1:2)+[floor(minX)-1, floor(minY)-1]; % convert to coordinates in whole image.
%         for i=1:CornersNumROI
%             dist_currentcorner  = sqrt(sum( ( CornerCoordsImg(i,:)-NbLensCoords ).^2  , 2 ));   % 计算每个点到微透镜中心的距离。
%             valueID             = find( dist_currentcorner<= (LensRadius-SearchThreshold) ); % 根据距离，进行筛选，剔除分布在边缘的检测点。
%             if ~isempty(valueID)
%                 CornerIDnoEdges         = [CornerIDnoEdges;i];
%                 LensIDperCorner        = [LensIDperCorner;  CurrentLensIDnearCorner(valueID) ];
%             end
%         end
%     end    
%     corners.p          = corners.p(CornerIDnoEdges,:);
%     corners.LensID     = LensIDperCorner;
%     corners.pImg       = CornerCoordsImg(CornerIDnoEdges,:);
%     corners.response   = corners.response(CornerIDnoEdges,:);
% end


function corners = RemoveCornersOnEdge(ROILeftCoords,corners,NbLensCoords,LensRadius,SearchThreshold,CurrentLensIDnearCorner)
    minX  = ROILeftCoords(1);
    minY  = ROILeftCoords(2);
    nCOR  = size(corners.p,1);

    LensIDperCorner   = zeros(0,1);   % 每个角点→1个微透镜ID（列向量）
    CornerIDnoEdges   = zeros(0,1);
    CornerCoordsImg   = [];

    if nCOR>0
        % ROI 坐标 → 全图坐标
        CornerCoordsImg = corners.p(:,1:2) + [floor(minX)-1, floor(minY)-1];

        % 过滤掉邻域中的 NaN 透镜/无效ID
        validLens = isfinite(NbLensCoords(:,1)) & isfinite(NbLensCoords(:,2)) & isfinite(CurrentLensIDnearCorner(:));
        NbLensCoordsValid             = NbLensCoords(validLens,:);
        CurrentLensIDnearCornerValid  = CurrentLensIDnearCorner(validLens);

        for i = 1:nCOR
            % 计算该角点到所有邻域透镜中心的距离
            d = hypot(CornerCoordsImg(i,1) - NbLensCoordsValid(:,1), ...
                      CornerCoordsImg(i,2) - NbLensCoordsValid(:,2));

            % 只要“最近的”一个；并用 (LensRadius - SearchThreshold) 作为内圈阈值
            [dmin, idxMin] = min(d);

            if ~isempty(dmin) && isfinite(dmin) && dmin <= (LensRadius - SearchThreshold)
                CornerIDnoEdges(end+1,1) = i;                               %#ok<AGROW>
                LensIDperCorner(end+1,1) = CurrentLensIDnearCornerValid(idxMin); %#ok<AGROW>
            end
        end
    end

    % 根据保留的角点索引裁剪各字段
    corners.p        = corners.p(CornerIDnoEdges,:);
    corners.pImg     = CornerCoordsImg(CornerIDnoEdges,:);
    corners.LensID   = LensIDperCorner;

    if isfield(corners,'response') && ~isempty(corners.response)
        corners.response = corners.response(CornerIDnoEdges,:);
    else
        corners.response = [];
    end
end
