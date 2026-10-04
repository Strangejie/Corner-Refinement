function [LensletGridModel, GridCoords, LensClass] = Generate(WhiteFile)

    S = load(WhiteFile, 'extracted_center_list');

    LensCenter = S.extracted_center_list(1:4, :);
    Kinds = S.extracted_center_list(5, :);
    [LensletGridModel, GridCoords] = LensCenter2GridCoords(LensCenter);

    k  = LensCenter(3,:); 
    l  = LensCenter(4,:); 
    k0 = min(k);
    l0 = min(l);

    rows = LensletGridModel.VMax;
    cols = LensletGridModel.UMax;

    rr = (k - k0 + 1);     
    cc = (l - l0 + 1);     

    TypeGrid = nan(rows, cols);
    for i = 1:numel(Kinds)
        r = rr(i); c = cc(i);
        if r>=1 && r<=rows && c>=1 && c<=cols
            LensClass(r, c) = Kinds(i);
        end
    end

end


function [LensletGridModel, GridCoords] = LensCenter2GridCoords(LensCenter)

    C = double(LensCenter);

    x = C(1,:);   
    y = C(2,:);   
    k = C(3,:);   
    l = C(4,:);   

    k0 = min(k);
    l0 = min(l);
    rows = max(k) - k0 + 1;   
    cols = max(l) - l0 + 1;   

    if sum(l == max(l)) < rows
        cols = cols-1;
    end

    GridCoords = nan(rows, cols, 2);  

    rr = (k - k0 + 1);
    cc = (l - l0 + 1);

    for i = 1:numel(x)
        r = rr(i); 
        c = cc(i);
        if r>=1 && r<=rows && c>=1 && c<=cols
            GridCoords(r, c, 1) = x(i); 
            GridCoords(r, c, 2) = y(i); 
        end
    end

    X = GridCoords(:,:,1);
    Y = GridCoords(:,:,2);

    dH = abs(X(:,2:end) - X(:,1:end-1));
    dH = dH(:); dH = dH(isfinite(dH));
    if isempty(dH), HSpacing = NaN; else, HSpacing = mean(dH); end

    dV = abs(Y(2:end,:) - Y(1:end-1,:));
    dV = dV(:); dV = dV(isfinite(dV));
    if isempty(dV), VSpacing = NaN; else, VSpacing = mean(dV); end

    LensletGridModel.HSpacing = HSpacing;
    LensletGridModel.UMax     = cols;
    LensletGridModel.VMax     = rows;
    LensletGridModel.VSpacing = VSpacing;
    LensletGridModel.Rot      = 0;
   
end


% function [LensletGridModel, GridCoords, LensClass] = Generate(WhiteFile, showFig)
% 
%     if nargin < 2, showFig = true; end
% 
%     % === 1) 读数据 ===
%     S = load(WhiteFile, 'extracted_center_list');
%     LensCenter = S.extracted_center_list(1:4, :);  % [x; y; k; l]
%     Kinds      = S.extracted_center_list(5, :);    % 分类标签(如 ABC=1/2/3 或 0/1/2)
% 
%     % === 2) 生成网格模型与像素坐标表 ===
%     [LensletGridModel, GridCoords] = LensCenter2GridCoords(LensCenter);
% 
%     % === 3) 将类别填入二维网格 (k,l -> 行列) ===
%     k  = LensCenter(3,:); 
%     l  = LensCenter(4,:); 
%     k0 = min(k);
%     l0 = min(l);
% 
%     rows = LensletGridModel.VMax;   % k 方向大小
%     cols = LensletGridModel.UMax;   % l 方向大小
%     rr   = (k - k0 + 1);            % 行索引
%     cc   = (l - l0 + 1);            % 列索引
% 
%     LensClass = nan(rows, cols);    % 用 NaN 表示无数据
%     for i = 1:numel(Kinds)
%         r = rr(i); c = cc(i);
%         if r>=1 && r<=rows && c>=1 && c<=cols
%             LensClass(r, c) = Kinds(i);
%         end
%     end
% 
%     % === 4) 可视化 ===
%     if showFig
%         visualizeLensClasses(GridCoords, LensClass, LensletGridModel);
%     end
% end
% 
% 
% function [LensletGridModel, GridCoords] = LensCenter2GridCoords(LensCenter)
%     C = double(LensCenter);
%     x = C(1,:);   y = C(2,:);   k = C(3,:);   l = C(4,:);
% 
%     k0 = min(k); l0 = min(l);
%     rows = max(k) - k0 + 1;   
%     cols = max(l) - l0 + 1;   
% 
%     % 某些采样边缘缺失时，避免最后一列全部为空
%     if sum(l == max(l)) < rows
%         cols = cols - 1;
%     end
% 
%     GridCoords = nan(rows, cols, 2);  
%     rr = (k - k0 + 1);
%     cc = (l - l0 + 1);
% 
%     for i = 1:numel(x)
%         r = rr(i); c = cc(i);
%         if r>=1 && r<=rows && c>=1 && c<=cols
%             GridCoords(r, c, 1) = x(i);  % 像素 x
%             GridCoords(r, c, 2) = y(i);  % 像素 y
%         end
%     end
% 
%     % 估计水平/竖直间距
%     X = GridCoords(:,:,1);
%     Y = GridCoords(:,:,2);
% 
%     dH = abs(X(:,2:end) - X(:,1:end-1)); dH = dH(:); dH = dH(isfinite(dH));
%     HSpacing = mean(dH,'omitnan');
% 
%     dV = abs(Y(2:end,:) - Y(1:end-1,:)); dV = dV(:); dV = dV(isfinite(dV));
%     VSpacing = mean(dV,'omitnan');
% 
%     LensletGridModel.HSpacing = HSpacing;
%     LensletGridModel.UMax     = cols;
%     LensletGridModel.VMax     = rows;
%     LensletGridModel.VSpacing = VSpacing;
%     LensletGridModel.Rot      = 0;
% end
% 
% 
% function visualizeLensClasses(GridCoords, LensClass, LG)
%     % --- 提取中心与类别 ---
%     [rows, cols, ~] = size(GridCoords);
%     X = GridCoords(:,:,1); Y = GridCoords(:,:,2);
% 
%     % 有效点掩码
%     M = isfinite(X) & isfinite(Y) & isfinite(LensClass);
% 
%     x = X(M); y = Y(M); c = LensClass(M);
%     if isempty(c)
%         warning('没有可视化的有效微透镜中心或类别标签。');
%         return;
%     end
% 
%     % --- 自动选择配色与图例文本 ---
%     u = sort(unique(c(:)'));  % 唯一类别
%     % 两套常见语义：{0,1,2} / {1,2,3}
%     if isequal(u, [0 1 2])
%         labels = {'0: 黑/白', '1: 边', '2: 角'};
%     elseif isequal(u, [1 2 3])
%         labels = {'1: A型', '2: B型', '3: C型'};
%     else
%         % 通用标签
%         labels = arrayfun(@(v) sprintf('类 %g', v), u, 'UniformOutput', false);
%     end
% 
%     % 生成与类别数量匹配的颜色与标记
%     % 颜色：MATLAB 默认色轮循环；标记：o, s, ^, d, v, >
%     baseMarkers = {'o','s','^','d','v','>'};
%     K = numel(u);
%     markers = baseMarkers(mod(0:K-1, numel(baseMarkers))+1);
% 
%     % --- 绘图 ---
%     figure('Name','Microlens Classification','Color','w'); hold on;
% 
%     % 1) 背景：用网格线弱化显示邻接关系（可选）
%     drawLightGrid(GridCoords, [0.8 0.8 0.8]);  % 浅灰
% 
%     % 2) 按类别分别散点绘制
%     hs = gobjects(1,K);
%     for i = 1:K
%         mask = (c == u(i));
%         hs(i) = scatter(x(mask), y(mask), 24, 'filled', 'Marker', markers{i});
%     end
% 
%     % 3) 设定坐标轴，标题与图例
%     axis equal ij; grid on;
%     xlabel('x (px)'); ylabel('y (px)');
%     title(sprintf('Microlens Classes | H=%.2f, V=%.2f | rows=%d, cols=%d', ...
%         LG.HSpacing, LG.VSpacing, LG.VMax, LG.UMax));
% 
%     % 统计数量
%     counts = arrayfun(@(val) sum(c==val), u);
%     legendStr = arrayfun(@(i) sprintf('%s (n=%d)', labels{i}, counts(i)), 1:K, 'UniformOutput', false);
%     legend(hs, legendStr, 'Location','bestoutside');
%     hold off;
% end
% 
% 
% function drawLightGrid(GridCoords, colorLine)
%     % 仅连接右邻与下邻，避免重复
%     [rows, cols, ~] = size(GridCoords);
%     X = GridCoords(:,:,1); Y = GridCoords(:,:,2);
%     for r = 1:rows
%         for c = 1:cols
%             if r<=rows && c<cols && all(isfinite([X(r,c),Y(r,c), X(r,c+1),Y(r,c+1)]))
%                 line([X(r,c), X(r,c+1)], [Y(r,c), Y(r,c+1)], 'Color', colorLine, 'LineWidth', 0.5);
%             end
%             if r<rows && c<=cols && all(isfinite([X(r,c),Y(r,c), X(r+1,c),Y(r+1,c)]))
%                 line([X(r,c), X(r+1,c)], [Y(r,c), Y(r+1,c)], 'Color', colorLine, 'LineWidth', 0.5);
%             end
%         end
%     end
% end

