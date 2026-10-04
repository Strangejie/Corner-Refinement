%% 极线和深度约束修改版，去CellRGBLensID（按Lensclass打分+排序）
function  [allPts, allClearPts, allOmega] = DetectCornersOurs(GridCoords, LensletGridModel, Lensclass, ConfigBag, varargin)
    MaxPDRadius       = 100;
    MinMeanResponse   = 0.015; % 角点质量门限（均值）
    DetectTresh       = 0.02;  % ROI 内检测阈值
    Filtersize        = 7;     % 预处理滤波窗口

    LensRadius                    = LensletGridModel.HSpacing/2;
    [FileList_raw, BasePath_raw]  = ReadRawImgInfo(ConfigBag.FilePath_Raw, ConfigBag.DefaultFileSpec_Raw);
    ImageNum                      = length(FileList_raw);

    % === 由 Lensclass 直接构三组 LensID（取值 1/2/3） ===
    CellRGBLensID = cell(3,1);
    for t = 1:3
        CellRGBLensID{t} = find(Lensclass==t);  
    end

    allPts      = cell(ImageNum,1);
    allClearPts = cell(ImageNum,1);
    allOmega    = cell(ImageNum,1);

    templateCell = CreateTemplate(ConfigBag.FilterRadius);

    for id = 1:ImageNum
        % === 读图 + 预处理 ===
        Img_raw_nonfilter   = ReadRawImg(BasePath_raw, FileList_raw, id);
        [Img_raw, Img_raw2] = ImagePreprocess(Img_raw_nonfilter, Filtersize, ConfigBag.delta, ConfigBag.Optdelta);

        % === 中央孔径粗检测，作为簇种子 ===
        ImgCenter           = FormCenterAperture(Img_raw, GridCoords);
        cornerCenter        = DetectCornersOnCentralAperture(ImgCenter, ConfigBag);

        % === 由种子得到每簇的邻域微透镜 ID ===
        LensIDnearCorner      = GetLensIDnearCorners(cornerCenter, ConfigBag.neighbrs, GridCoords, LensletGridModel);
        CornerNumCurrentFrame = size(LensIDnearCorner,1);

        % === 本帧输出容器 ===
        CellCornerInfoPerFrame      = cell(CornerNumCurrentFrame,1);
        CellClearCornerInfoPerFrame = cell(CornerNumCurrentFrame,1);
        CellOmegaPerFrame           = cell(CornerNumCurrentFrame,1);
        
        % === 逐簇处理 ===
        for corn_id = 1:CornerNumCurrentFrame
            CurrentLensIDnearCorner = LensIDnearCorner(corn_id,:);
            [corners1, corners2, RawROI] = DetectCorner(CurrentLensIDnearCorner, Img_raw, LensRadius, GridCoords, LensletGridModel, templateCell, ConfigBag, DetectTresh, false); %#ok<NASGU>

            [corners, CornerType] = ChooseCornerSet( corners1, corners2, GridCoords, LensRadius, ConfigBag, MinMeanResponse, false, RawROI);
            
            % 增加类型保护：如果返回的 corners 不是结构体，说明没检测到角点，直接跳过
            if ~isstruct(corners)
                continue;
            end
            
            isReliable = (CornerType ~= 0) && ~isempty(corners.response) && (mean(corners.response) >= MinMeanResponse) && (size(corners.p,1) >= 2);
            if ~isReliable
                % 此时已确保 corners 是结构体，可以安全使用 .p 索引
                if isfield(corners, 'p') && size(corners.p,1) == 1
                    CellCornerInfoPerFrame{corn_id}      = [corners.pImg, corners.LensID];
                    CellClearCornerInfoPerFrame{corn_id} = [corners.pImg, corners.LensID];
                    CellOmegaPerFrame{corn_id}           = [];
                end
                continue;
            end

            %% =====================================================================================

            % —— 在这里先计算 FocusScore，用于三组打分排序 —— 
            [corners, ImgBag] = CalculateCornerOrientationAndFocusScore(RawROI, corners);

            % —— 三组打分（按 corners.LensID → Lensclass 分组），取均值作为得分 ——
            lensTypes = Lensclass(corners.LensID);
            meanScore = -inf(3,1); cnt = zeros(3,1);
            for t = 1:3
                idx = (lensTypes == t);
                if any(idx)
                    meanScore(t) = mean(corners.FocusScore(idx));
                    cnt(t)       = sum(idx);
                end
            end

            [~, orderTypes] = sortrows([meanScore, cnt], [-1, -1]);  % 先按分数降序，再按数量降序
            orderTypes = orderTypes(:)';  % best, mid, worst

            corners = applyEpiDepthConstraint_byOrder(corners, GridCoords, Lensclass, orderTypes);

            ClearType = orderTypes(1);

            [Omega, ClearPts_perCorner] = OptimizeCorner(corners, CellRGBLensID, ClearType, Img_raw2, Img_raw, GridCoords, LensRadius, ConfigBag, templateCell, CornerType, false);

            if isempty(Omega) || abs(Omega(3)) >= MaxPDRadius, continue; end

            % 0) 不再用 CurrentLensIDnearCorner 过滤；直接用全局投影补齐角点
            ProjAll     = ProjectPDF2Img(Omega, GridCoords, LensRadius, -1, ConfigBag.ProjTresh);  % [x y LensID]
            ProjCluster = FilterProjectedCornersOnEdge(ProjAll, GridCoords, LensRadius, ConfigBag.SearchThreshold);
            
            % 1) 将投影得到的“缺失微透镜”的角点补入 corners（只补缺）
            oldN    = numel(corners.LensID);
            missIDs = setdiff(ProjCluster(:,3), corners.LensID);
            if ~isempty(missIDs)
                mskNew          = ismember(ProjCluster(:,3), missIDs);
                corners.pImg    = [corners.pImg;   ProjCluster(mskNew,1:2)];
                corners.p       = [corners.p;      ProjCluster(mskNew,1:2)];   % 局部坐标先用全局代替
                corners.LensID  = [corners.LensID; ProjCluster(mskNew,3)];
            end
            
            % 2) 组装本簇数据
            lensIDs_cluster     = corners.LensID;
            GridCoordsX         = GridCoords(:,:,1);
            GridCoordsY         = GridCoords(:,:,2);
            MicCenters_cluster  = [GridCoordsX(lensIDs_cluster), GridCoordsY(lensIDs_cluster)];
            CornerPts_cluster   = corners.pImg;
            LensClass_vec       = Lensclass(lensIDs_cluster);
            
            % 标记哪些是投影新补的（便于 clear 输出时排除）
            isNew               = false(numel(lensIDs_cluster),1);
            isNew(oldN+1:end)   = true;
            
            % ======================================================================
            % 3) TriangleScaling 径向缩放校正
            % ======================================================================
            % 【消融实验切换指南】
            % 配合 TriangleScaling.m 中的消融实验块使用：
            %
            % 当前默认：完整版（全部透镜 + 三角网 + 统一s + Delta）
            %
            % 切换到指定实验的步骤：
            %   1. 在 TriangleScaling.m 中注释掉 L575-695 的完整版
            %   2. 取消注释目标实验对应的代码块
            %   3. 本文件的调用行保持不变（所有实验的接口签名一致）
            %
            % 实验对照：
            %   实验0（基线）       -> 注释掉下面的调用行，改用下两行的恒等映射
            %   实验1（去掉Delta）   -> TriangleScaling.m: 消融实验1 块
            %   实验2（仅清晰透镜）  -> TriangleScaling.m: 消融实验2 块
            %   实验3（无角度过滤）  -> TriangleScaling.m: 消融实验3 块
            %   实验4（去三角网）    -> TriangleScaling.m: 消融实验4 块
            %   实验5（去s+Delta）   -> TriangleScaling.m: 消融实验5 块
            %   实验6（加权版）      -> TriangleScaling.m: 消融实验6 块
            %
            % 【实验0/5 快捷方式：取消注释下面两行，同时注释掉 TriangleScaling 调用行】
%             CornerPts_cluster_new = CornerPts_cluster;
%             s_cluster_ignored = NaN;  %#ok<NASGU>
            % ======================================================================
            [CornerPts_cluster_new, ~, ~] = TriangleScaling( Omega, MicCenters_cluster, CornerPts_cluster, LensClass_vec, false);
            
            % 回写更新后的角点
            deltaG         = CornerPts_cluster_new - corners.pImg;
            corners.pImg   = CornerPts_cluster_new;
            corners.p      = corners.p + deltaG;
            
            % 4) 极线+虚拟深度约束（best→mid→worst）
            corners = applyEpiDepthConstraint_byOrder(corners, GridCoords, Lensclass, orderTypes);
            
            % 5) 输出：直接把更新后的角点作为结果；clear 集仅保留“原本检测到的清晰点”
            ProjPtsPerCorner   = [corners.pImg, corners.LensID];
            idxDetectedClear   = (LensClass_vec==3) & ~isNew;
            ClearPts_perCorner = [corners.pImg(idxDetectedClear,:), lensIDs_cluster(idxDetectedClear)];
            % ========= PATCH END =========


%%  

            % ==============一个文件保存===============
            CellCornerInfoPerFrame{corn_id}      = ProjPtsPerCorner;
            CellClearCornerInfoPerFrame{corn_id} = ClearPts_perCorner;
            CellOmegaPerFrame{corn_id}           = Omega;

            % ===============分开保存==================

            % === 按帧单独保存（OurNewDetectResults + 棋盘格名称）===
            rawname = local_get_raw_basename(FileList_raw, id);  % 取该帧原图基名
            outfile = fullfile(ConfigBag.FilePath_Raw, ['OurNewDetectResults_' rawname '.mat']);
            
            % 为了好读，这里用单帧变量名保存；你也可以沿用原名
            allPts_single      = CellCornerInfoPerFrame;
            allClearPts_single = CellClearCornerInfoPerFrame;
            allOmega_single    = CellOmegaPerFrame;
            
            save(outfile, 'allPts_single', 'allClearPts_single', 'allOmega_single');


        end

        drawnow;
        allPts{id}      = CellCornerInfoPerFrame;
        allClearPts{id} = CellClearCornerInfoPerFrame;
        allOmega{id}    = CellOmegaPerFrame;

        ShowResultofSingleFrame(Img_raw, CellCornerInfoPerFrame);
    end
end


% ========= 扩散式极线+深度约束：按(best, mid, worst)顺序 =========
function corners_out = applyEpiDepthConstraint_byOrder(corners, GridCoords, Lensclass, orderTypes)
    corners_out = corners;
    if size(corners.pImg,1) < 2, return; end

    % 三组索引
    typesAll = Lensclass(corners.LensID);
    idx_best = find(typesAll == orderTypes(1));
    idx_mid  = find(typesAll == orderTypes(2));
    idx_wst  = find(typesAll == orderTypes(3));

    % 微透镜中心（像素）
    cx = GridCoords(:,:,1); cy = GridCoords(:,:,2);
    getC = @(idx) [ cx(corners.LensID(idx)), cy(corners.LensID(idx)) ];

    % ===== Stage A：best → mid =====
    if numel(idx_best) >= 2 && ~isempty(idx_mid)
        clearPts_A     = corners_out.pImg(idx_best,:);    % 参考：best
        clearCenters_A = getC(idx_best);
        blurPts_A      = corners_out.pImg(idx_mid,:);     % 被修正：mid
        blurCenters_A  = getC(idx_mid);

        corrMid = epiDepthRefineCluster_localV(clearPts_A, clearCenters_A, blurPts_A,  blurCenters_A, [], true);
        dG      = corrMid - corners_out.pImg(idx_mid,:);
        corners_out.pImg(idx_mid,:) = corrMid;
        corners_out.p(idx_mid,:)    = corners_out.p(idx_mid,:) + dG;
    end

    % ===== Stage B：{best, mid} → worst =====
    idxRef = [idx_best(:); idx_mid(:)];
    if numel(idxRef) >= 2 && ~isempty(idx_wst)
        clearPts_B     = corners_out.pImg(idxRef,:);   % 参考集合
        clearCenters_B = getC(idxRef);
        blurPts_B      = corners_out.pImg(idx_wst,:);  % 被修正：worst
        blurCenters_B  = getC(idx_wst);

        corrWst = epiDepthRefineCluster_localV(clearPts_B, clearCenters_B, blurPts_B,  blurCenters_B, [], true);
        dG      = corrWst - corners_out.pImg(idx_wst,:);
        corners_out.pImg(idx_wst,:) = corrWst;
        corners_out.p(idx_wst,:)    = corners_out.p(idx_wst,:) + dG;
    end
end


% ========= 局部 v 的极线+深度约束（和你之前的一致） =========
function blurPts_corr = epiDepthRefineCluster_localV(clearPts, clearCenters, blurPts, blurCenters, adjRadiusPix, useMedianV)
    if nargin<5 || isempty(adjRadiusPix)
        if size(clearCenters,1)>=2
            estPitch = median(pdist(clearCenters));
        elseif size(blurCenters,1)>=2
            estPitch = median(pdist(blurCenters));
        else
            estPitch = 20;
        end
        adjRadiusPix = 1.6 * estPitch;
    end
    if nargin<6, useMedianV = false; end

    Nb = size(blurPts,1);
    blurPts_corr = blurPts;

    for k = 1:Nb
        Cm = blurCenters(k,:);
        d2c = sqrt(sum((clearCenters - Cm).^2, 2));
        neigh = find(d2c <= adjRadiusPix);
        if numel(neigh) < 2, continue; end

        % (9) v = |Mj-Mi| / (|Mj-Mi| - |Ij-Ii|)
        v_list = [];
        for ii = 1:numel(neigh)-1
            i = neigh(ii);
            for jj = ii+1:numel(neigh)
                j = neigh(jj);
                b = norm(clearCenters(j,:) - clearCenters(i,:));
                d = norm(clearPts(j,:)     - clearPts(i,:));
                if abs(b - d) > 1e-9
                    v_list(end+1,1) = b / (b - d);  %#ok<AGROW>
                end
            end
        end
        if isempty(v_list), continue; end
        v_hat = useMedianV * median(v_list) + (~useMedianV) * mean(v_list);

        % (10) Im' = Ir + ê * ( |Mm-Mr| - |Mm-Mr|/v_hat )
        preds = zeros(numel(neigh),2);
        wts   = zeros(numel(neigh),1);
        for t = 1:numel(neigh)
            r   = neigh(t);
            Cr  = clearCenters(r,:);
            Ir  = clearPts(r,:);
            dCrm = Cm - Cr;
            br   = norm(dCrm);
            if br < 1e-9
                preds(t,:) = Ir;  wts(t) = 1; continue;
            end
            ehat = dCrm / br;
            preds(t,:) = Ir + ehat * ( br - br / v_hat );
            wts(t)     = 1 / (1 + d2c(r));
        end
        wts = wts / sum(wts);
        blurPts_corr(k,:) = sum(preds .* wts, 1);
    end
end

function base = local_get_raw_basename(FileList_raw, idx)
    if iscell(FileList_raw)
        f = FileList_raw{idx};
    elseif isstruct(FileList_raw) && isfield(FileList_raw,'name')
        f = FileList_raw(idx).name;
    else
        f = char(FileList_raw(idx));
    end
    [~, base, ~] = fileparts(f);
end
