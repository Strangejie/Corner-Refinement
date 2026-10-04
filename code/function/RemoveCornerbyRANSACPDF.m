function [corners,MaxSetOrient] = RemoveCornerbyRANSACPDF( corners,GridCoords,  LensRadius,   Error_Inner, MinMeanResponse, Method)
    % if there is only two corners. the corner orientation is the dominent
    % factor.
    MaxOrienConsist             = 0.6; % 0.3
    V1                          = corners.v1;
    V2                          = corners.v2;
    response                    = corners.response;    
    allPts_perCorner            = [corners.pImg,corners.LensID];    
    RANSACEvaluteMethod         =  Method;%'score';
    EpipolarDist                = 5 ; % should relatively large.
    GridCoordsX                 = GridCoords(:,:,1);
    GridCoordsY                 = GridCoords(:,:,2);
    center_list                 = [GridCoordsX(:),GridCoordsY(:)]';  
    MaxInnerNum                 = 0;
    MaxInnerCornerID            = [];
    MinError                    = 10000;
    MaxSetScore                 = -1000;
    MaxSetOrient                = 1000;
    CornerNumCurrent            = size(allPts_perCorner,1);     % 当前检测出的特征点的总数。    
    if isempty(allPts_perCorner)
        return;
    end
    LensUniqueID                = unique(allPts_perCorner(:,3));   % 检测出特征点的微透镜编号。
    BreakFlag                   = false;
    for i = 1:CornerNumCurrent-1   % iterate through all corners.
        if  BreakFlag == true
            break;
        end
        for j= i+1:CornerNumCurrent
            % 加入判断条件，判断是否是规定微透镜类型。
            if ~ismember(allPts_perCorner(i,3),LensUniqueID)
                continue;
            end
            if ~ismember(allPts_perCorner(j,3),LensUniqueID)
                continue;
            end
            LensIDRef                       = allPts_perCorner(i,3);    % 提取参考点的数据
            CornerRefCoord                  = allPts_perCorner(i,1:2);
            LensRefCenterCoord              = [ center_list( 1, LensIDRef )',center_list( 2, LensIDRef )' ];
            LensIDComp                      = allPts_perCorner(j,3);    % 提取对照点的数据
            CornerCompCoord                 = allPts_perCorner(j,1:2);
            LensCompCenterCoord             = [ center_list( 1, LensIDComp )',center_list( 2, LensIDComp )' ];
            if LensIDRef ~= LensIDComp  % 如果不是同一个微透镜
                EpipolarVector              = LensCompCenterCoord- LensRefCenterCoord;
                Distance_Center             = sqrt( sum( EpipolarVector.^2, 2 ) );
                EpipolarUnitVector          = EpipolarVector./Distance_Center;
                CornerVector                = CornerCompCoord - CornerRefCoord;
                Dist_CornerEpipolar         = sqrt( sum( ( cross( [EpipolarUnitVector,0]  ,[CornerVector,0]) ).^2) );
                if Dist_CornerEpipolar< EpipolarDist   % 要找到在对极线范围内的点来进行计算。
                    % 计算 pdf
                    CurrentPts = [allPts_perCorner(i,:);allPts_perCorner(j,:)];
                    Omega      = CalculatePlenopticDiscFeatureLSM(CurrentPts,GridCoords );                    
                    if ( abs(Omega(3)) >= 2 ) && ( abs(Omega(3))<20 )  %  给虚深度设置一个大致范围，防止无效计算。
                        Corner_microImg_Coord       = ProjectPDF2Img(Omega, GridCoords, LensRadius,LensUniqueID ,0);
                        [InnerCornerID, CountInnerNum , ErrorMean] = RANSACCalculateInnerCorner( Corner_microImg_Coord, allPts_perCorner, Error_Inner); % 根据投影点和实测点，计算内点。                                                                      
                        if strcmp(RANSACEvaluteMethod,'score')
                            v1_currentset               = V1(InnerCornerID,:);
                            v2_currentset               = V2(InnerCornerID,:);
                            response_currentset            = response(InnerCornerID,:);
                            [ScoreSet,OrientScoreAve]   = CalculateCornerSetScore(v1_currentset,v2_currentset,response_currentset, CountInnerNum);
                            if ScoreSet > MaxSetScore
                                MaxInnerCornerID                = InnerCornerID;  % 找到最大内点序列
                                MaxSetScore                     = ScoreSet;
                                MaxSetOrient                    = OrientScoreAve;
                                if ( size(MaxInnerCornerID,1) > 0.7*CornerNumCurrent ) && (OrientScoreAve<MaxOrienConsist)
                                    BreakFlag = true;
                                    break;
                                end
                            end
                        else 
                            if strcmp(RANSACEvaluteMethod,'number')
                                if CountInnerNum > MaxInnerNum || (CountInnerNum==MaxInnerNum)&&( ErrorMean < MinError) % 对最大内点序列的数据进行记录。
                                    MaxInnerNum                     = CountInnerNum;
                                    MinError                        = ErrorMean;
                                    MaxInnerCornerID                = InnerCornerID;  % 找到最大内点序列。
                                    if ( size(MaxInnerCornerID,1) > 0.7*CornerNumCurrent ) 
                                        BreakFlag = true;
                                        break;
                                    end
                                end
                            end
                        end
                        
                        
                    end
                end
            end
        end
    end
    
    CornerNum            = size(MaxInnerCornerID,1);
    [~,OrientScoreAve]   = CalculateCornerSetScore(  V1(MaxInnerCornerID,:) ,  V2(MaxInnerCornerID,:) , response(MaxInnerCornerID,:), CornerNum);
    if CornerNum <= 2
        LowScore  = sum( corners.response(MaxInnerCornerID)< MinMeanResponse ) ; 
        if  LowScore==0 && OrientScoreAve < MaxOrienConsist
            corners = UpdateCorner(corners,MaxInnerCornerID);
            return;
        else
            MaxInnerCornerID = [];
            corners = UpdateCorner(corners,MaxInnerCornerID);
            return;
        end
    else
        MeanResponse  = mean( corners.response(MaxInnerCornerID)) ; 
        if MeanResponse < MinMeanResponse || OrientScoreAve > MaxOrienConsist
            corners = UpdateCorner(corners,[]);
        else
            corners = UpdateCorner(corners,MaxInnerCornerID);     
        end
          
    end


end



function [ScoreSet,OrientScoreAve] = CalculateCornerSetScore(v1_currentset,v2_currentset,score_currentset,CountInnerNum)

% 可能方向计算这里除了问题。
    v1             = v1_currentset;
    v2             = v2_currentset;    
    OrientScoreAve = CalculateOrientationConsistency(v1,v2);
    AverageScore   = mean(score_currentset);
    ScoreSet       = AverageScore*CountInnerNum*(1-OrientScoreAve);
end






% function clusters = RemoveCornerbyRANSACPDF(corners, GridCoords, LensRadius, Error_Inner, MinMeanResponse, Method)
% % 多簇版包装器：循环剥离每轮的最大一致集
% % 依赖：你原来的 RemoveCornerbyRANSACPDF（单簇）和 UpdateCorner
% %
% % 输出 clusters 为元胞数组，每个元素是一个角点结构体（同 corners 字段集）
% 
%     % -------- 参数与初始化 --------
%     fields = {'p','pImg','LensID','v1','v2','response','focusScore','score'};
%     N0 = size(corners.p,1);
%     remain = (1:N0).';                 % 剩余索引（列向量）
%     clusters = {};
%     MaxIter = 10;                      % 最多提取多少簇
%     MinInliers = 4;                    % 最小内点数阈值
% 
%     if N0 < MinInliers
%         return;
%     end
% 
%     % 为了稳健匹配内点：构造“容差键”
%     key_all = make_key(corners);       % N0×1 字符串（包含四舍五入的 p/pImg + LensID）
% 
%     % -------- 迭代剥离 --------
%     iter = 0;
%     while numel(remain) >= MinInliers && iter < MaxIter
%         iter = iter + 1;
% 
%         % 在剩余集合上构造子结构 sub
%         sub = corners;
%         for f = 1:numel(fields)
%             if isfield(sub, fields{f})
%                 sub.(fields{f}) = sub.(fields{f})(remain, :);
%             end
%         end
% 
%         % 调用“单簇版” 找本轮最大一致集
%         subOut = RemoveCornerbyRANSACPDF(sub, GridCoords, LensRadius, Error_Inner, MinMeanResponse, Method);
% 
%         % 可能为空（本轮找不到一致集）
%         if ~isstruct(subOut) || ~isfield(subOut,'p') || isempty(subOut.p)
%             break;
%         end
% 
%         % 用“容差键+LensID”匹配内点在 sub 中的位置，再还原回原全集索引
%         key_sub    = make_key(sub);
%         key_subOut = make_key(subOut);
%         % ismember 字符串匹配不会出现浮点精度问题
%         [tf, loc] = ismember(key_subOut, key_sub);
% 
%         if ~all(tf)
%             % 理论上不会；防御：丢掉匹配失败的
%             loc = loc(tf);
%         end
%         if isempty(loc) || numel(loc) < MinInliers
%             break;
%         end
% 
%         inlier_idx_global = remain(loc);  % 还原到原全集的索引
% 
%         % 存一份本轮簇（保留原字段）
%         clusters{end+1} = UpdateCorner(corners, inlier_idx_global); %#ok<AGROW>
% 
%         % 从剩余集合中剥离本轮内点
%         mask = true(numel(remain),1);
%         mask(loc) = false;
%         remain = remain(mask);
%     end
% end
% 
% function key = make_key(c)
% % 生成稳健匹配用的键：round 到 1e-2 像素 + LensID
% % 优先用 pImg（全图坐标），没有则退回 p（ROI 相对坐标）
% 
%     if isfield(c,'pImg')
%         xy = c.pImg;
%     elseif isfield(c,'pimg')
%         xy = c.pimg;
%     else
%         xy = c.p;   % 退而求其次
%     end
%     if ~isfield(c,'LensID')
%         error('角点结构缺少 LensID 字段，无法做跨轮匹配。');
%     end
% 
%     % 避免浮点误差：保留 0.01 像素精度
%     x = round(xy(:,1), 2);
%     y = round(xy(:,2), 2);
%     lid = c.LensID(:);
% 
%     % 拼成字符串键（不会产生 N×N 隐式扩展）
%     key = string(x) + "_" + string(y) + "_" + string(lid);
% end
