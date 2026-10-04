% %% 狄洛尼三角网版
% % function [CornerPts_new, s_each] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
% % 
% %     % 角度过滤参数（去掉近乎共线/极度细长的三角形） 
% %     minAngleDeg = 10; 
% %     maxAngleDeg = 170;
% %     if nargin < 5
% %         debug = false; 
% %     end
% % 
% %     O = Omega(1:2);
% % 
% %     % 仅用清晰微透镜（类型==3）
% %     validMask = (LensClass == 3) & all(isfinite(CornerPts),2);
% %     idxValid  = find(validMask);
% %     if numel(idxValid) < 3
% %         CornerPts_new = CornerPts;
% %         s_each = nan(size(CornerPts,1),1);
% %         return;
% %     end
% % 
% %     Mv = MicCenters(idxValid,:);   % 清晰微透镜中心
% %     Pv = CornerPts(idxValid,:);    % 对应角点
% % 
% %     % 三角剖分（以清晰微透镜中心为顶点）
% %     DT = delaunayTriangulation(Mv(:,1), Mv(:,2));
% %     triList = DT.ConnectivityList;      % T×3
% % 
% %     % 收集每个“顶点”的所有 s_t，最后聚合
% %     s_accum = cell(size(Mv,1),1);
% % 
% %     for t = 1:size(triList,1)
% %         vIdx = triList(t,:);
% % 
% %         % 角度过滤
% %         if ~isTriangleAngleOK(Mv(vIdx,:), minAngleDeg, maxAngleDeg), continue; end
% % 
% %         % 该三角形的统一缩放 s_t:  最小化 Σ || O + s*(Mᵥ-O) - Pᵥ ||^2
% %         d = Mv(vIdx,:) - O(:)';    % 3×2,  Mᵥ-O
% %         q = Pv(vIdx,:) - O(:)';    % 3×2,  Pᵥ-O
% % 
% %         nume = sum( sum(d .* q, 2) );   % Σ dot(dᵥ, qᵥ)
% %         deno = sum( sum(d .* d, 2) );   % Σ ||dᵥ||^2
% %         if deno < 1e-12, continue; end
% % 
% %         s_t = nume / deno;
% % 
% %         % 如需限制 s_t 合理范围，可启用（当前按你的要求不启用）
% %         % if ~(s_t > 0 && s_t < 2.0), continue; end
% % 
% %         % 该三角形把同一个 s_t 分配给它的三个顶点
% %         for k = 1:3
% %             s_accum{ vIdx(k) }(end+1,1) = s_t;
% %         end
% %     end
% % 
% %     % 顶点聚合（同一点可能出现在多个三角形中）
% %     AGG = @mean;  % 若想更抗异常，改成 @median
% %     s_avg_local = nan(size(Mv,1),1);
% %     for i = 1:size(Mv,1)
% %         if ~isempty(s_accum{i})
% %             s_avg_local(i) = AGG(s_accum{i});
% %         else
% %             % 兜底：该点未被任何合格三角形覆盖，退化为“单点径向缩放”
% %             d_i = Mv(i,:) - O(:)'; q_i = Pv(i,:) - O(:)';
% %             deno_i = sum(d_i.^2);
% %             if deno_i > 1e-12
% %                 s_avg_local(i) = (d_i * q_i') / deno_i;  % 标量
% %             end
% %         end
% %     end
% % 
% %     % 用聚合后的 s 更新角点：Pᵢ(new) = O + sᵢ*(Mᵢ-O)
% %     Pv_new = Pv;
% %     for i = 1:size(Mv,1)
% %         s_here = s_avg_local(i);
% %         if isfinite(s_here)
% %             Pv_new(i,:) = O(:)' + s_here * (Mv(i,:) - O(:)');
% %         end
% %     end
% % 
% %     % 写回到全体角点数组
% %     CornerPts_new = CornerPts;
% %     CornerPts_new(idxValid,:) = Pv_new;
% % 
% %     s_each = nan(size(CornerPts,1),1);
% %     s_each(idxValid) = s_avg_local;
% % 
% %     if debug
% %         figure; hold on; axis equal ij;
% %         title('radial scaling per-triangle (angle filter only)');
% %         plot(MicCenters(:,1), MicCenters(:,2), 'y+', 'MarkerSize', 6, 'LineWidth', 1.2);
% %         plot(CornerPts(:,1),  CornerPts(:,2),  'mx', 'MarkerSize', 6, 'LineWidth', 1.2);
% %         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go', 'MarkerSize',5,'LineWidth',1);
% %         plot(O(1),O(2),'g+','MarkerSize',10,'LineWidth',1.5);
% %         % 画三角形骨架（仅清晰子集）
% %         for t = 1:size(triList,1)
% %             tri = triList(t,:);
% %             if ~isTriangleAngleOK(Mv(tri,:), minAngleDeg, maxAngleDeg), continue; end
% %             pts = Mv(tri,:);
% %             plot([pts(:,1); pts(1,1)], [pts(:,2); pts(1,2)], 'Color',[1 .6 0], 'LineWidth',0.8);
% %         end
% %         legend({'mic centers','corners old','corners new','Omega'}, 'Location','bestoutside');
% %         hold off;
% %     end
% % end
% % 
% % function ok = isTriangleAngleOK(P, minAngDeg, maxAngDeg)
% %     ok = true;
% %     for a = 1:3
% %         b = mod(a,3)+1; c = mod(a+1,3)+1;
% %         v1 = P(b,:) - P(a,:); v2 = P(c,:) - P(a,:);
% %         n1 = norm(v1); n2 = norm(v2);
% %         if n1<1e-9 || n2<1e-9, ok=false; return; end
% %         cosang = dot(v1,v2)/(n1*n2);
% %         cosang = max(min(cosang,1),-1);
% %         ang = acosd(cosang);
% %         if ang < minAngDeg || ang > maxAngDeg
% %             ok = false; return;
% %         end
% %     end
% % end



%% 圆心-中心三角网版
% function [CornerPts_new, s_each] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 角度阈值（对三顶点 O/Mi/Mj 全部检查）
%     minAngleDeg = 10;
%     maxAngleDeg = 170;
%     if nargin < 5, debug = false; end
% 
%     O = Omega(1:2);
% 
%     % 仅用清晰微透镜（类型==3）
%     validMask = (LensClass == 3) & all(isfinite(CornerPts),2);
%     idxValid  = find(validMask);
%     CornerPts_new = CornerPts;
%     s_each        = nan(size(CornerPts,1),1);
%     if numel(idxValid) < 2, return; end
% 
%     % 清晰子集（保持原顺序）
%     Mv = MicCenters(idxValid,:);   % 清晰中心
%     Pv = CornerPts(idxValid,:);    % 对应角点
% 
%     % === 用清晰中心做 Delaunay，取中心—中心边 ===
%     DT    = delaunayTriangulation(Mv(:,1), Mv(:,2));
%     pairs = edges(DT);                         % Ex2，每行 (i,j)
%     if isempty(pairs), return; end
% 
%     Nv = size(Mv,1);
%     s_accum    = cell(Nv,1);                  % 顶点收集多个 s_t
%     usedVertex = false(Nv,1);
%     usedEdge   = false(size(pairs,1),1);
% 
%     % === 遍历每条边，构成三角形 (O, Mi, Mj) ===
%     for r = 1:size(pairs,1)
%         i = pairs(r,1); j = pairs(r,2);
% 
%         % 三个顶点坐标
%         Mi = Mv(i,:);  Mj = Mv(j,:);
% 
%         % —— 角度过滤：三个顶点都要在 [min,max] 内 ——
%         if ~triAllAnglesOK(O, Mi, Mj, minAngleDeg, maxAngleDeg)
%             continue;
%         end
% 
%         % —— 在该三角形上估统一缩放 s_t（沿 O→M 方向）——
%         d = [Mi - O(:)'; Mj - O(:)'];      % 2×2,   M - O
%         q = [Pv(i,:) - O(:)'; Pv(j,:) - O(:)']; % 2×2, P - O
% 
%         deno = sum(sum(d.^2,2));           % Σ ||d||^2
%         if deno < 1e-12, continue; end
%         nume = sum(sum(d .* q, 2));        % Σ dot(d,q)
%         s_t  = nume / deno;                % 闭式解（L2 最小二乘）
% 
%         % 分配给两个端点
%         s_accum{i}(end+1,1) = s_t;
%         s_accum{j}(end+1,1) = s_t;
%         usedVertex([i j]) = true;
%         usedEdge(r) = true;
%     end
% 
%     if ~any(usedVertex), return; end
% 
%     % === 顶点聚合（均值；更抗异常可改 @median） ===
%     AGG = @mean;
%     s_avg_local = nan(Nv,1);
%     for i = 1:Nv
%         if ~isempty(s_accum{i})
%             s_avg_local(i) = AGG(s_accum{i});
%         else
%             % 兜底：单点径向比
%             d_i = Mv(i,:) - O(:)'; q_i = Pv(i,:) - O(:)';
%             di2 = sum(d_i.^2);
%             if di2 > 1e-12, s_avg_local(i) = (d_i*q_i')/di2; end
%         end
%     end
% 
%     % === 用聚合后的 s 更新角点：P_new = O + s*(M - O) ===
%     Pv_new = Pv;
%     for i = 1:Nv
%         s_here = s_avg_local(i);
%         if isfinite(s_here)
%             Pv_new(i,:) = O(:)' + s_here * (Mv(i,:) - O(:)');
%         end
%     end
% 
%     % 写回全体
%     CornerPts_new(idxValid,:) = Pv_new;
%     s_each(idxValid)          = s_avg_local;
% 
%     % === 调试：只画参与计算的边与径向 ===
%     if debug
%         figure; hold on; axis equal ij;
%         title('O-anchored triangles with full angle filter & radial scaling');
% 
%         plot(O(1),O(2),'g+','MarkerSize',10,'LineWidth',1.5);
%         plot(MicCenters(:,1), MicCenters(:,2), 'y+', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts(:,1),  CornerPts(:,2),  'mx', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5,'LineWidth',1);
% 
%         % 只画用到的径向
%         vid = find(usedVertex);
%         for k = 1:numel(vid)
%             mi = Mv(vid(k),:);
%             plot([O(1) mi(1)], [O(2) mi(2)], 'Color',[1 .8 .2], 'LineWidth',0.9);
%         end
% 
%         % 只画通过角度过滤且被使用的中心—中心边
%         pairs_used = pairs(usedEdge,:);
%         for r = 1:size(pairs_used,1)
%             mi = Mv(pairs_used(r,1),:);
%             mj = Mv(pairs_used(r,2),:);
%             plot([mi(1) mj(1)], [mi(2) mj(2)], 'Color',[1 .6 0], 'LineWidth',1.0);
%         end
%         legend({'Omega','mic centers','corners old','corners new'}, 'Location','bestoutside');
%         hold off;
%     end
% end
% 
% % ===== 辅助：检查三角形三个顶点的内角是否都在阈值内 =====
% function ok = triAllAnglesOK(O, Mi, Mj, minDeg, maxDeg)
%     ok = true;
%     % 顶点 O 的角：∠MiOMj
%     if ~angleOK(Mi - O, Mj - O, minDeg, maxDeg), ok=false; return; end
%     % 顶点 Mi 的角：∠OMiMj
%     if ~angleOK(O - Mi, Mj - Mi, minDeg, maxDeg), ok=false; return; end
%     % 顶点 Mj 的角：∠OMjMi
%     if ~angleOK(O - Mj, Mi - Mj, minDeg, maxDeg), ok=false; return; end
% end
% 
% function tf = angleOK(v1, v2, minDeg, maxDeg)
%     n1 = norm(v1); n2 = norm(v2);
%     if n1 < 1e-12 || n2 < 1e-12, tf = false; return; end
%     c = max(min(dot(v1,v2)/(n1*n2),1),-1);
%     ang = acosd(c);
%     tf = (ang >= minDeg) && (ang <= maxDeg);
% end

%% 1111111111
% function [CornerPts_new, s_each, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 角度阈值（对三顶点 O/Mi/Mj 全部检查）
%     minAngleDeg = 10;
%     maxAngleDeg = 170;
%     if nargin < 5, debug = false; end
% 
%     O  = Omega(1:2);
%     O  = O(:)';                      % 1x2
%     epsDen = 1e-9;                   % 防止除零
%     dO = [0, 0];                     % 默认圆心偏移
% 
%     % 仅用清晰微透镜（类型==3）
%     validMask = (LensClass == 3) & all(isfinite(CornerPts),2);
%     idxValid  = find(validMask);
%     CornerPts_new = CornerPts;
%     s_each        = nan(size(CornerPts,1),1);
%     if numel(idxValid) < 2, return; end
% 
%     % 清晰子集（保持原顺序）
%     Mv = MicCenters(idxValid,:);   % 清晰中心
%     Pv = CornerPts(idxValid,:);    % 对应角点
% 
%     % === Delaunay 生成中心—中心边 ===
%     DT    = delaunayTriangulation(Mv(:,1), Mv(:,2));
%     pairs = edges(DT);                         % Ex2，每行 (i,j)
%     if isempty(pairs), return; end
% 
%     % === 先在每个三角形上闭式估计 s_t 与 Δ_t，再聚合全局 Δ ===
%     dO_list = [];  w_list = [];               % 收集 Δ_t 与权重 w_t
%     usedEdge = false(size(pairs,1),1);
% 
%     for r = 1:size(pairs,1)
%         i = pairs(r,1); j = pairs(r,2);
%         Mi = Mv(i,:);     Mj = Mv(j,:);
%         if ~triAllAnglesOK(O, Mi, Mj, minAngleDeg, maxAngleDeg), continue; end
% 
%         % 记 a_v = M - O, c_v = O - P  （v=i,j）
%         ai = Mi - O;       aj = Mj - O;
%         ci = O  - Pv(i,:); cj = O  - Pv(j,:);
% 
%         % 去中心化：A~ = a - mean_a, C~ = c - mean_c
%         mean_a = 0.5 * (ai + aj);
%         mean_c = 0.5 * (ci + cj);
%         A1 = ai - mean_a;  A2 = aj - mean_a;
%         C1 = ci - mean_c;  C2 = cj - mean_c;
% 
%         denS = sum(A1.^2) + sum(A2.^2);              % Σ||A~||^2
%         if denS < epsDen, continue; end
%         numS = dot(A1, C1) + dot(A2, C2);            % Σ A~·C~
%         s_t  = - numS / denS;                        % —— 闭式：最小化残差后对 s 的解
% 
%         k = (1 - s_t);
%         if abs(k) < 1e-6
%             % s≈1 时 Δ 不可观；跳过该三角形的 Δ 估计
%             continue;
%         end
% 
%         % Δ_t* = - mean( s*a + c ) / (1 - s)
%         mean_sa_c = 0.5 * ( s_t*ai + ci + s_t*aj + cj );
%         dO_t = - mean_sa_c / k;                      % 1x2
% 
%         % 权重：用 denS（几何分散度）更稳
%         dO_list(end+1,:) = dO_t;                     %#ok<AGROW>
%         w_list(end+1,1)  = denS;                     %#ok<AGROW>
%         usedEdge(r) = true;
%     end
% 
%     % 全局 Δ 聚合（加权平均；也可用@median 加权中位数）
%     if ~isempty(w_list)
%         dO = (w_list' * dO_list) / sum(w_list);
%     else
%         dO = [0,0];  % 没有可用三角形则不偏移
%     end
%     O2 = O + dO;     % 新圆心
% 
%     % === 用 O2 重新估计每条边的 s_t，再对顶点聚合 ===
%     Nv = size(Mv,1);
%     s_accum    = cell(Nv,1);
%     usedVertex = false(Nv,1);
% 
%     for r = 1:size(pairs,1)
%         if ~usedEdge(r), continue; end
%         i = pairs(r,1); j = pairs(r,2);
%         Mi = Mv(i,:);   Mj = Mv(j,:);
%         if ~triAllAnglesOK(O2, Mi, Mj, minAngleDeg, maxAngleDeg), continue; end
% 
%         d = [Mi - O2; Mj - O2];    % 2x2
%         q = [Pv(i,:) - O2; Pv(j,:) - O2];
% 
%         deno = sum(sum(d.^2,2));   % Σ||d||^2
%         if deno < epsDen, continue; end
%         nume = sum(sum(d .* q, 2));% Σ d·q
%         s_t  = nume / deno;
% 
%         s_accum{i}(end+1,1) = s_t;
%         s_accum{j}(end+1,1) = s_t;
%         usedVertex([i j]) = true;
%     end
% 
%     % 顶点聚合（均值；更抗异常可换 @median）
%     AGG = @mean;
%     s_avg_local = nan(Nv,1);
%     for i = 1:Nv
%         if ~isempty(s_accum{i})
%             s_avg_local(i) = AGG(s_accum{i});
%         else
%             % 兜底：单点径向比（用 O2）
%             di2 = Mv(i,:) - O2;
%             qi2 = Pv(i,:) - O2;
%             d2  = sum(di2.^2);
%             if d2 > epsDen
%                 s_avg_local(i) = dot(di2, qi2) / d2;
%             end
%         end
%     end
% 
%     % 用 O2 与 s_i 更新角点：P_i(new) = O2 + s_i*(M_i - O2)
%     Pv_new = Pv;
%     for i = 1:Nv
%         s_here = s_avg_local(i);
%         if isfinite(s_here)
%             Pv_new(i,:) = O2 + s_here * (Mv(i,:) - O2);
%         end
%     end
% 
%     % 写回到全体角点数组
%     CornerPts_new(idxValid,:) = Pv_new;
%     s_each(idxValid)          = s_avg_local;
% 
%     % —— 调试只画“参与计算”的边与径向 ——
%     if debug
%         figure; hold on; axis equal ij;
%         title('TriangleScaling with center shift (Δ) + full angle filter');
%         plot(O(1), O(2), 'c+', 'MarkerSize', 9, 'LineWidth', 1.2);      % 原圆心
%         plot(O2(1),O2(2),'g+', 'MarkerSize', 10,'LineWidth', 1.6);      % 新圆心
%         plot(MicCenters(:,1), MicCenters(:,2), 'y+', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts(:,1),  CornerPts(:,2),  'mx', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5,'LineWidth',1);
% 
%         % 用到的顶点与边
%         vid = find(usedVertex);
%         for k = 1:numel(vid)
%             mi = Mv(vid(k),:);
%             plot([O2(1) mi(1)],[O2(2) mi(2)],'Color',[1 .8 .2],'LineWidth',0.9);
%         end
%         pairs_used = pairs(usedEdge,:);
%         for r = 1:size(pairs_used,1)
%             mi = Mv(pairs_used(r,1),:);
%             mj = Mv(pairs_used(r,2),:);
%             plot([mi(1) mj(1)],[mi(2) mj(2)],'Color',[1 .6 0],'LineWidth',1.0);
%         end
%         legend({'O','O2','mic centers','corners old','corners new'},'Location','bestoutside');
%         hold off;
%     end
% end
% 
% % ===== 三顶点角度都需在阈值内 =====
% function ok = triAllAnglesOK(O, Mi, Mj, minDeg, maxDeg)
%     ok = angleOK(Mi - O,  Mj - O,  minDeg, maxDeg) && ...
%          angleOK(O  - Mi, Mj - Mi, minDeg, maxDeg) && ...
%          angleOK(O  - Mj, Mi - Mj, minDeg, maxDeg);
% end
% 
% function tf = angleOK(v1, v2, minDeg, maxDeg)
%     n1 = norm(v1); n2 = norm(v2);
%     if n1 < 1e-12 || n2 < 1e-12, tf = false; return; end
%     c = max(min(dot(v1,v2)/(n1*n2),1),-1);
%     ang = acosd(c);
%     tf = (ang >= minDeg) && (ang <= maxDeg);
% end



%% dxdy+s联合优化
% function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 先构成三角网（有角度要求），再用“整簇单一 s + 圆心微偏移 Δ”闭式解
%     % 仅对参与三角形的“清晰=3”角点更新；未参与者保持不变
%     %
%     % 输入:
%     %   Omega(1:2) = [Ox, Oy] 初始PDF圆心
%     %   MicCenters : N×2 微透镜中心全图坐标
%     %   CornerPts  : N×2 对应角点全图坐标
%     %   LensClass  : N×1 取值1/2/3（仅 3 为清晰）
%     %   debug      : 是否可视化（仅画参与计算的三角形）
%     %
%     % 输出:
%     %   CornerPts_new : 更新后的角点坐标（仅清晰且参与三角形者会变）
%     %   s_cluster     : 本簇统一缩放 s（闭式）
%     %   dO            : 圆心微偏移 Δ=[dx,dy]（闭式）
%     %
%     if nargin<5, debug=false; end
%     O   = Omega(1:2);  O = O(:)';       % 圆心
%     epsDen = 1e-9;
%     minAngleDeg = 10;                   % 三角形角度门限
%     maxAngleDeg = 170;
% 
%     CornerPts_new = CornerPts;
%     s_cluster = NaN;
%     dO = [0,0];
% 
%     % 仅取“清晰=3”且坐标有效的点
%     idxClear = (LensClass==3) & all(isfinite(CornerPts),2);
%     if nnz(idxClear) < 2, return; end
% 
%     M_all = MicCenters(idxClear,:);     % 清晰中心（子集）
%     P_all = CornerPts(idxClear,:);      % 清晰角点（子集）
% 
%     % === 用清晰中心做 Delaunay，取中心—中心边 ===
%     DT    = delaunayTriangulation(M_all(:,1), M_all(:,2));
%     pairs = edges(DT);                   % Ex2，每行 (i,j) 指向清晰子集的索引
%     if isempty(pairs), return; end
% 
%     % === 过滤出“合格三角形”：(O, Mi, Mj) 三个顶点角度都在 [min,max] ===
%     keep = false(size(pairs,1),1);
%     for r = 1:size(pairs,1)
%         i = pairs(r,1); j = pairs(r,2);
%         Mi = M_all(i,:);  Mj = M_all(j,:);
%         keep(r) = triAllAnglesOK(O, Mi, Mj, minAngleDeg, maxAngleDeg);
%     end
%     pairs_used = pairs(keep,:);
%     if isempty(pairs_used), return; end
% 
%     % === 仅用这些合格三角形“涉及到的清晰点”参与后续联合优化 ===
%     usedIdx_local = unique(pairs_used(:));          % 清晰子集里的局部索引
%     M = M_all(usedIdx_local,:);                     % 参与联合优化的清晰中心
%     P = P_all(usedIdx_local,:);                     % 参与联合优化的清晰角点
% 
%     % === 整簇单一 s + Δ 闭式解（只对参与三角形的清晰点） ===
%     A = M - O;                   % a_v = M - O
%     C = O - P;                   % c_v = O - P
%     Abar = mean(A,1);  Cbar = mean(C,1);
%     Atil = A - Abar;   Ctil = C - Cbar;
% 
%     den = sum(sum(Atil.^2,2));   % Σ||Â||^2
%     if den < epsDen, return; end
% 
%     num = sum(sum(Atil .* Ctil, 2));  % Σ(Â·Ĉ)
%     s   = - num / den;                % 全簇统一 s（闭式）
%     % 如需限制 s 的范围，可启用下行（可选）
%     % s = max(min(s, 2.0), 0.0);
% 
%     % Δ(s)；当 s≈1 时 Δ 不可观，置零
%     if abs(1 - s) < 1e-3
%         Delta = [0,0];
%     else
%         Delta = - (s*Abar + Cbar) / (1 - s);   % Δ = - (s ā + ċ)/(1-s)
%     end
%     O2 = O + Delta;
% 
%     % === 用 O2 与统一 s 更新“参与三角形的清晰点”： P_new = O2 + s*(M - O2) ===
%     P_new_local = O2 + s * (M - O2);
% 
%     % 写回到全体坐标（仅更新“清晰且参与三角形”的那些）
%     CornerPts_new(idxClear, :) = CornerPts(idxClear, :);   % 先拷贝
%     tmp = CornerPts_new(idxClear, :);
%     tmp(usedIdx_local, :) = P_new_local;
%     CornerPts_new(idxClear, :) = tmp;
% 
%     s_cluster = s;
%     dO = Delta;
% 
%     % === 可视化：仅绘参与计算的三角形与径向 ===
%     if debug
%         figure; hold on; axis equal ij;
%         title(sprintf('Mesh (angle-filtered) + joint single-s (s=%.4f), dO=[%.3f,%.3f]', s, dO(1), dO(2)));
% 
%         % 点
%         plot(O(1),O(2),'c+','LineWidth',1.2,'MarkerSize',9);         % 原圆心
%         plot(O2(1),O2(2),'g+','LineWidth',1.5,'MarkerSize',10);      % 新圆心
%         plot(MicCenters(:,1), MicCenters(:,2), 'y+', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts(:,1),  CornerPts(:,2),  'mx', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5,'LineWidth',1);
% 
%         % 只画“参与的清晰点”的径向
%         for k = 1:numel(usedIdx_local)
%             mi = M( k ,:);
%             plot([O2(1) mi(1)], [O2(2) mi(2)], 'Color',[1 .8 .2], 'LineWidth', 0.9);
%         end
% 
%         % 只画“通过角度过滤并用于计算”的中心—中心边 + 连接到 O2 的两条边（即三角形）
%         for r = 1:size(pairs_used,1)
%             i = pairs_used(r,1); j = pairs_used(r,2);
%             mi = M_all(i,:); mj = M_all(j,:);
%             % 中心-中心边
%             plot([mi(1) mj(1)], [mi(2) mj(2)], 'Color',[1 .6 0], 'LineWidth', 1.0);
%             % O2-中心边（两条，构成 (O2,Mi,Mj) 三角形）
%             plot([O2(1) mi(1)], [O2(2) mi(2)], 'Color',[0 .5 1], 'LineStyle','-', 'LineWidth', 0.8);
%             plot([O2(1) mj(1)], [O2(2) mj(2)], 'Color',[0 .5 1], 'LineStyle','-', 'LineWidth', 0.8);
%         end
% 
%         legend({'O','O2','mic centers','corners old','corners new'}, 'Location','bestoutside');
%         hold off;
%     end
% end
% 
% % ===== 三顶点角度都需在阈值内 =====
% function ok = triAllAnglesOK(O, Mi, Mj, minDeg, maxDeg)
%     ok = angleOK(Mi - O,  Mj - O,  minDeg, maxDeg) && ...
%          angleOK(O  - Mi, Mj - Mi, minDeg, maxDeg) && ...
%          angleOK(O  - Mj, Mi - Mj, minDeg, maxDeg);
% end
% 
% function tf = angleOK(v1, v2, minDeg, maxDeg)
%     n1 = norm(v1); n2 = norm(v2);
%     if n1 < 1e-12 || n2 < 1e-12, tf = false; return; end
%     c = max(min(dot(v1,v2)/(n1*n2),1),-1);
%     ang = acosd(c);
%     tf = (ang >= minDeg) && (ang <= maxDeg);
% end


%% 模糊角点

% function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 不区分清晰/模糊，使用“全部透镜”参与构网与优化（仅坐标需有效）
%     % 先构角度筛选的三角网 → 仅用通过筛选的三角形“涉及到的点”做整簇单一 s + Δ 闭式解
%     % 仅更新这些参与点的角点坐标；未参与者保持不变
%     %
%     % 输入:
%     %   Omega(1:2) = [Ox, Oy] 初始PDF圆心
%     %   MicCenters : N×2 微透镜中心全图坐标
%     %   CornerPts  : N×2 对应角点全图坐标
%     %   LensClass  : N×1 (本函数不再使用，仅为兼容签名)
%     %   debug      : 是否可视化（仅画参与计算的三角形）
%     %
%     % 输出:
%     %   CornerPts_new : 更新后的角点坐标（仅参与三角者会变）
%     %   s_cluster     : 本簇统一缩放 s（闭式）
%     %   dO            : 圆心微偏移 Δ=[dx,dy]（闭式）
%     %
%     if nargin<5, debug=false; end
%     O   = Omega(1:2);  O = O(:)';       % 圆心
%     epsDen = 1e-9;
%     minAngleDeg = 10;                   % 三角形角度门限
%     maxAngleDeg = 170;
% 
%     CornerPts_new = CornerPts;
%     s_cluster = NaN;
%     dO = [0,0];
% 
%     % ==== 参与范围：所有坐标有效的点 ====
%     idxValid = all(isfinite(MicCenters),2) & all(isfinite(CornerPts),2);
%     if nnz(idxValid) < 2, return; end
% 
%     M_all = MicCenters(idxValid,:);     % 子集：有效中心
%     P_all = CornerPts(idxValid,:);      % 子集：有效角点
% 
%     % ==== 用“所有有效中心”做 Delaunay，取中心—中心边 ====
%     DT    = delaunayTriangulation(M_all(:,1), M_all(:,2));
%     pairs = edges(DT);                   % Ex2，每行 (i,j) 指向“有效子集”的局部索引
%     if isempty(pairs), return; end
% 
%     % ==== 过滤出“合格三角形”：(O, Mi, Mj) 的三个顶点角都在 [min,max] ====
%     keep = false(size(pairs,1),1);
%     for r = 1:size(pairs,1)
%         i = pairs(r,1); j = pairs(r,2);
%         Mi = M_all(i,:);  Mj = M_all(j,:);
%         keep(r) = triAllAnglesOK(O, Mi, Mj, minAngleDeg, maxAngleDeg);
%     end
%     pairs_used = pairs(keep,:);
%     if isempty(pairs_used), return; end
% 
%     % ==== 仅用这些合格三角“涉及到的点”进入联合优化 ====
%     usedIdx_local = unique(pairs_used(:));          % 相对于“有效子集”的局部索引
%     M = M_all(usedIdx_local,:);                     % 参与优化的中心
%     P = P_all(usedIdx_local,:);                     % 参与优化的角点
% 
%     % ==== 整簇单一 s + Δ 闭式解（仅对参与点集） ====
%     A = M - O;                   % a_v = M - O
%     C = O - P;                   % c_v = O - P
%     Abar = mean(A,1);  Cbar = mean(C,1);
%     Atil = A - Abar;   Ctil = C - Cbar;
% 
%     den = sum(sum(Atil.^2,2));   % Σ||Â||^2
%     if den < epsDen, return; end
% 
%     num = sum(sum(Atil .* Ctil, 2));  % Σ(Â·Ĉ)
%     s   = - num / den;                % 全簇统一 s（闭式）
%     % 可选：限制 s 范围
%     % s = max(min(s, 2.0), 0.0);
% 
%     % Δ(s)；当 s≈1 时 Δ 不可观，置零
%     if abs(1 - s) < 1e-3
%         Delta = [0,0];
%     else
%         Delta = - (s*Abar + Cbar) / (1 - s);   % Δ = - (s ā + ċ)/(1-s)
%     end
%     O2 = O + Delta;
% 
%     % ==== 用 O2 与统一 s 更新“参与三角形的点”： P_new = O2 + s*(M - O2) ====
%     P_new_local = O2 + s * (M - O2);
% 
%     % 写回到全体坐标（仅更新“有效且参与三角”的那些）
%     CornerPts_new(idxValid, :) = CornerPts(idxValid, :);   % 先拷贝
%     tmp = CornerPts_new(idxValid, :);
%     tmp(usedIdx_local, :) = P_new_local;
%     CornerPts_new(idxValid, :) = tmp;
% 
%     s_cluster = s;
%     dO = Delta;
% 
%     % ==== 可视化：仅绘参与计算的三角形与径向 ====
%     if debug
%         figure; hold on; axis equal ij;
%         title(sprintf('ALL-lenses mesh (angle-filtered) + joint single-s (s=%.4f), dO=[%.3f,%.3f]', s, dO(1), dO(2)));
% 
%         % 点
%         plot(O(1),O(2),'c+','LineWidth',1.2,'MarkerSize',9);         % 原圆心
%         plot(O2(1),O2(2),'g+','LineWidth',1.5,'MarkerSize',10);      % 新圆心
%         plot(MicCenters(:,1), MicCenters(:,2), 'y+', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts(:,1),  CornerPts(:,2),  'mx', 'MarkerSize', 6, 'LineWidth', 1.2);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5,'LineWidth',1);
% 
%         % 只画“参与的点”的径向（O2→Mi）
%         for k = 1:numel(usedIdx_local)
%             mi = M(k,:);
%             plot([O2(1) mi(1)], [O2(2) mi(2)], 'Color',[1 .8 .2], 'LineWidth', 0.9);
%         end
% 
%         % 只画“通过角度过滤并用于计算”的中心—中心边 + 连接到 O2 的两条边（即三角形）
%         for r = 1:size(pairs_used,1)
%             i = pairs_used(r,1); j = pairs_used(r,2);
%             mi = M_all(i,:); mj = M_all(j,:);
%             % 中心-中心边
%             plot([mi(1) mj(1)], [mi(2) mj(2)], 'Color',[1 .6 0], 'LineWidth', 1.0);
%             % O2-中心边（两条）
%             plot([O2(1) mi(1)], [O2(2) mi(2)], 'Color',[0 .5 1], 'LineStyle','-', 'LineWidth', 0.8);
%             plot([O2(1) mj(1)], [O2(2) mj(2)], 'Color',[0 .5 1], 'LineStyle','-', 'LineWidth', 0.8);
%         end
% 
%         legend({'O','O2','mic centers','corners old','corners new'}, 'Location','bestoutside');
%         hold off;
%     end
% end

% % ===== 三顶点角度都需在阈值内 =====
% function ok = triAllAnglesOK(O, Mi, Mj, minDeg, maxDeg)
%     ok = angleOK(Mi - O,  Mj - O,  minDeg, maxDeg) && ...
%          angleOK(O  - Mi, Mj - Mi, minDeg, maxDeg) && ...
%          angleOK(O  - Mj, Mi - Mj, minDeg, maxDeg);
% end
% 
% function tf = angleOK(v1, v2, minDeg, maxDeg)
%     n1 = norm(v1); n2 = norm(v2);
%     if n1 < 1e-12 || n2 < 1e-12, tf = false; return; end
%     c = max(min(dot(v1,v2)/(n1*n2),1),-1);
%     ang = acosd(c);
%     tf = (ang >= minDeg) && (ang <= maxDeg);
% end


%% ================================================================
%% 消融实验模块
%% 使用方法：
%%   1. 注释掉 L575-695 的当前激活版本（完整版）
%%   2. 取消注释下面其中一个实验块
%%   3. 所有实验共用底部的 triAllAnglesOK 和 angleOK 辅助函数
%%   （实验4、5不需要三角网，但保留辅助函数不会影响运行）
%%
%% 快速索引：
%%   实验1（去掉Δ）       →  L731-816    消融实验1 块
%%   实验2（仅清晰透镜）    →  L818-906    消融实验2 块
%%   实验3（去掉角度过滤）  →  L909-999    消融实验3 块
%%   实验4（去三角网，逐点） →  L1001-1070  消融实验4 块
%%   实验5（去s+Δ，恒等）   →  L1052-1071  消融实验5 块
%%   实验6（加权版）        →  L1078-1212  消融实验6 块（原加权版）
%% ================================================================


%% ===== 消融实验1：去掉圆心偏移Δ，仅保留统一缩放s =====
% function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 消融实验1：强制 Δ=[0,0]，只估计统一缩放 s
%     % 三角网 + 角度过滤 + 全部透镜 保持不变
%     if nargin<5, debug=false; end
%     O   = Omega(1:2);  O = O(:)';
%     epsDen = 1e-9;
%     minAngleDeg = 10;
%     maxAngleDeg = 170;
% 
%     CornerPts_new = CornerPts;
%     s_cluster = NaN;
%     dO = [0,0];
% 
%     idxValid = all(isfinite(MicCenters),2) & all(isfinite(CornerPts),2);
%     if nnz(idxValid) < 2, return; end
% 
%     M_all = MicCenters(idxValid,:);
%     P_all = CornerPts(idxValid,:);
% 
%     DT    = delaunayTriangulation(M_all(:,1), M_all(:,2));
%     pairs = edges(DT);
%     if isempty(pairs), return; end
% 
%     keep = false(size(pairs,1),1);
%     for r = 1:size(pairs,1)
%         i = pairs(r,1); j = pairs(r,2);
%         Mi = M_all(i,:);  Mj = M_all(j,:);
%         keep(r) = triAllAnglesOK(O, Mi, Mj, minAngleDeg, maxAngleDeg);
%     end
%     pairs_used = pairs(keep,:);
%     if isempty(pairs_used), return; end
% 
%     usedIdx_local = unique(pairs_used(:));
%     M = M_all(usedIdx_local,:);
%     P = P_all(usedIdx_local,:);
% 
%     % === 整簇统一 s（去中心化闭式解） ===
%     A = M - O;
%     C = O - P;
%     Abar = mean(A,1);  Cbar = mean(C,1);
%     Atil = A - Abar;   Ctil = C - Cbar;
% 
%     den = sum(sum(Atil.^2,2));
%     if den < epsDen, return; end
%     num = sum(sum(Atil .* Ctil, 2));
%     s   = - num / den;
% 
%     % ★ 消融关键：强制 Δ=[0,0] ★
%     Delta = [0,0];
%     O2 = O;                      % 圆心不做偏移
% 
%     P_new_local = O2 + s * (M - O2);
% 
%     CornerPts_new(idxValid, :) = CornerPts(idxValid, :);
%     tmp = CornerPts_new(idxValid, :);
%     tmp(usedIdx_local, :) = P_new_local;
%     CornerPts_new(idxValid, :) = tmp;
% 
%     s_cluster = s;
%     dO = Delta;
% 
%     if debug
%         figure; hold on; axis equal ij;
%         title(sprintf('Ablation-1: NO Delta (s=%.4f, dO=[0,0])', s));
%         plot(O(1),O(2),'c+','LineWidth',1.2,'MarkerSize',9);
%         plot(O2(1),O2(2),'g+','LineWidth',1.5,'MarkerSize',10);
%         plot(MicCenters(:,1),MicCenters(:,2),'y+','MarkerSize',6);
%         plot(CornerPts(:,1),CornerPts(:,2),'mx','MarkerSize',6);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5);
%         for k = 1:numel(usedIdx_local)
%             mi = M(k,:);
%             plot([O2(1) mi(1)],[O2(2) mi(2)],'Color',[1 .8 .2],'LineWidth',0.9);
%         end
%         for r = 1:size(pairs_used,1)
%             i = pairs_used(r,1); j = pairs_used(r,2);
%             mi = M_all(i,:); mj = M_all(j,:);
%             plot([mi(1) mj(1)],[mi(2) mj(2)],'Color',[1 .6 0],'LineWidth',1.0);
%             plot([O2(1) mi(1)],[O2(2) mi(2)],'Color',[0 .5 1],'LineStyle','-','LineWidth',0.8);
%             plot([O2(1) mj(1)],[O2(2) mj(2)],'Color',[0 .5 1],'LineStyle','-','LineWidth',0.8);
%         end
%         legend({'O(=O2)','O2','mic centers','corners old','corners new'},'Location','bestoutside');
%         hold off;
%     end
% end


%% ===== 消融实验2：仅用清晰透镜（LensClass==3） =====
% function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 消融实验2：仅用清晰透镜参与三角网 + 联合优化
%     % 三角网 + 角度过滤 + 统一 s + Δ 保持不变，但排除模糊透镜
%     if nargin<5, debug=false; end
%     O   = Omega(1:2);  O = O(:)';
%     epsDen = 1e-9;
%     minAngleDeg = 10;
%     maxAngleDeg = 170;
% 
%     CornerPts_new = CornerPts;
%     s_cluster = NaN;
%     dO = [0,0];
% 
%     % ★ 消融关键：仅取 LensClass==3 且坐标有效 ★
%     idxValid = (LensClass==3) & all(isfinite(MicCenters),2) & all(isfinite(CornerPts),2);
%     if nnz(idxValid) < 2, return; end
% 
%     M_all = MicCenters(idxValid,:);
%     P_all = CornerPts(idxValid,:);
% 
%     DT    = delaunayTriangulation(M_all(:,1), M_all(:,2));
%     pairs = edges(DT);
%     if isempty(pairs), return; end
% 
%     keep = false(size(pairs,1),1);
%     for r = 1:size(pairs,1)
%         i = pairs(r,1); j = pairs(r,2);
%         Mi = M_all(i,:);  Mj = M_all(j,:);
%         keep(r) = triAllAnglesOK(O, Mi, Mj, minAngleDeg, maxAngleDeg);
%     end
%     pairs_used = pairs(keep,:);
%     if isempty(pairs_used), return; end
% 
%     usedIdx_local = unique(pairs_used(:));
%     M = M_all(usedIdx_local,:);
%     P = P_all(usedIdx_local,:);
% 
%     % === 整簇统一 s + Δ 闭式解 ===
%     A = M - O;
%     C = O - P;
%     Abar = mean(A,1);  Cbar = mean(C,1);
%     Atil = A - Abar;   Ctil = C - Cbar;
% 
%     den = sum(sum(Atil.^2,2));
%     if den < epsDen, return; end
%     num = sum(sum(Atil .* Ctil, 2));
%     s   = - num / den;
% 
%     if abs(1 - s) < 1e-3
%         Delta = [0,0];
%     else
%         Delta = - (s*Abar + Cbar) / (1 - s);
%     end
%     O2 = O + Delta;
% 
%     P_new_local = O2 + s * (M - O2);
% 
%     CornerPts_new(idxValid, :) = CornerPts(idxValid, :);
%     tmp = CornerPts_new(idxValid, :);
%     tmp(usedIdx_local, :) = P_new_local;
%     CornerPts_new(idxValid, :) = tmp;
% 
%     s_cluster = s;
%     dO = Delta;
% 
%     if debug
%         figure; hold on; axis equal ij;
%         title(sprintf('Ablation-2: Clear-only (s=%.4f, dO=[%.3f,%.3f])', s, dO(1), dO(2)));
%         plot(O(1),O(2),'c+','LineWidth',1.2,'MarkerSize',9);
%         plot(O2(1),O2(2),'g+','LineWidth',1.5,'MarkerSize',10);
%         plot(MicCenters(:,1),MicCenters(:,2),'y+','MarkerSize',6);
%         plot(CornerPts(:,1),CornerPts(:,2),'mx','MarkerSize',6);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5);
%         for k = 1:numel(usedIdx_local)
%             mi = M(k,:);
%             plot([O2(1) mi(1)],[O2(2) mi(2)],'Color',[1 .8 .2],'LineWidth',0.9);
%         end
%         for r = 1:size(pairs_used,1)
%             i = pairs_used(r,1); j = pairs_used(r,2);
%             mi = M_all(i,:); mj = M_all(j,:);
%             plot([mi(1) mj(1)],[mi(2) mj(2)],'Color',[1 .6 0],'LineWidth',1.0);
%             plot([O2(1) mi(1)],[O2(2) mi(2)],'Color',[0 .5 1],'LineStyle','-','LineWidth',0.8);
%             plot([O2(1) mj(1)],[O2(2) mj(2)],'Color',[0 .5 1],'LineStyle','-','LineWidth',0.8);
%         end
%         legend({'O','O2','mic centers','corners old','corners new'},'Location','bestoutside');
%         hold off;
%     end
% end


%% ===== 消融实验3：去掉角度过滤 =====
% function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 消融实验3：不筛选三角形角度，所有 Delaunay 边都参与
%     % 全部透镜 + 三角网 + 统一 s + Δ 保持不变，但 minAngleDeg=0, maxAngleDeg=180
%     if nargin<5, debug=false; end
%     O   = Omega(1:2);  O = O(:)';
%     epsDen = 1e-9;
%     % ★ 消融关键：角度阈值放宽到极限 ★
%     minAngleDeg = 0;
%     maxAngleDeg = 180;
% 
%     CornerPts_new = CornerPts;
%     s_cluster = NaN;
%     dO = [0,0];
% 
%     idxValid = all(isfinite(MicCenters),2) & all(isfinite(CornerPts),2);
%     if nnz(idxValid) < 2, return; end
% 
%     M_all = MicCenters(idxValid,:);
%     P_all = CornerPts(idxValid,:);
% 
%     DT    = delaunayTriangulation(M_all(:,1), M_all(:,2));
%     pairs = edges(DT);
%     if isempty(pairs), return; end
% 
%     % 角度过滤形同虚设（0~180 包含所有三角形）
%     keep = false(size(pairs,1),1);
%     for r = 1:size(pairs,1)
%         i = pairs(r,1); j = pairs(r,2);
%         Mi = M_all(i,:);  Mj = M_all(j,:);
%         keep(r) = triAllAnglesOK(O, Mi, Mj, minAngleDeg, maxAngleDeg);
%     end
%     pairs_used = pairs(keep,:);
%     if isempty(pairs_used), return; end
% 
%     usedIdx_local = unique(pairs_used(:));
%     M = M_all(usedIdx_local,:);
%     P = P_all(usedIdx_local,:);
% 
%     % === 整簇统一 s + Δ 闭式解 ===
%     A = M - O;
%     C = O - P;
%     Abar = mean(A,1);  Cbar = mean(C,1);
%     Atil = A - Abar;   Ctil = C - Cbar;
% 
%     den = sum(sum(Atil.^2,2));
%     if den < epsDen, return; end
%     num = sum(sum(Atil .* Ctil, 2));
%     s   = - num / den;
% 
%     if abs(1 - s) < 1e-3
%         Delta = [0,0];
%     else
%         Delta = - (s*Abar + Cbar) / (1 - s);
%     end
%     O2 = O + Delta;
% 
%     P_new_local = O2 + s * (M - O2);
% 
%     CornerPts_new(idxValid, :) = CornerPts(idxValid, :);
%     tmp = CornerPts_new(idxValid, :);
%     tmp(usedIdx_local, :) = P_new_local;
%     CornerPts_new(idxValid, :) = tmp;
% 
%     s_cluster = s;
%     dO = Delta;
% 
%     if debug
%         figure; hold on; axis equal ij;
%         title(sprintf('Ablation-3: No angle filter (s=%.4f, dO=[%.3f,%.3f])', s, dO(1), dO(2)));
%         plot(O(1),O(2),'c+','LineWidth',1.2,'MarkerSize',9);
%         plot(O2(1),O2(2),'g+','LineWidth',1.5,'MarkerSize',10);
%         plot(MicCenters(:,1),MicCenters(:,2),'y+','MarkerSize',6);
%         plot(CornerPts(:,1),CornerPts(:,2),'mx','MarkerSize',6);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5);
%         for k = 1:numel(usedIdx_local)
%             mi = M(k,:);
%             plot([O2(1) mi(1)],[O2(2) mi(2)],'Color',[1 .8 .2],'LineWidth',0.9);
%         end
%         for r = 1:size(pairs_used,1)
%             i = pairs_used(r,1); j = pairs_used(r,2);
%             mi = M_all(i,:); mj = M_all(j,:);
%             plot([mi(1) mj(1)],[mi(2) mj(2)],'Color',[1 .6 0],'LineWidth',1.0);
%             plot([O2(1) mi(1)],[O2(2) mi(2)],'Color',[0 .5 1],'LineStyle','-','LineWidth',0.8);
%             plot([O2(1) mj(1)],[O2(2) mj(2)],'Color',[0 .5 1],'LineStyle','-','LineWidth',0.8);
%         end
%         legend({'O','O2','mic centers','corners old','corners new'},'Location','bestoutside');
%         hold off;
%     end
% end


%% ===== 消融实验4：去掉三角网，逐点独立径向缩放 =====
% function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 消融实验4：完全不用 Delaunay 三角网
%     % 每个点独立计算 s_i = <M_i-O, P_i-O> / ||M_i-O||^2
%     % 无联合优化、无 Δ、无角度过滤
%     if nargin<5, debug=false; end
%     O = Omega(1:2);  O = O(:)';
%     epsDen = 1e-9;
% 
%     CornerPts_new = CornerPts;
%     s_cluster = NaN;
%     dO = [0,0];
% 
%     idxValid = all(isfinite(MicCenters),2) & all(isfinite(CornerPts),2);
%     if nnz(idxValid) < 1, return; end
% 
%     M = MicCenters(idxValid,:);
%     P = CornerPts(idxValid,:);
%     Nv = size(M,1);
% 
%     % ★ 消融关键：逐点独立 s_i，无三角网结构 ★
%     d = M - O;
%     q = P - O;
%     s_each = nan(Nv,1);
%     for i = 1:Nv
%         den_i = sum(d(i,:).^2);
%         if den_i > epsDen
%             s_each(i) = dot(d(i,:), q(i,:)) / den_i;
%         end
%     end
% 
%     s_cluster = mean(s_each, 'omitnan');
%     dO = [0,0];
% 
%     % 逐点更新：P_i_new = O + s_i * (M_i - O)
%     P_new = O + s_each .* d;
%     CornerPts_new(idxValid,:) = P_new;
% 
%     if debug
%         figure; hold on; axis equal ij;
%         title(sprintf('Ablation-4: Per-point radial (no mesh, mean s=%.4f)', s_cluster));
%         plot(O(1),O(2),'g+','MarkerSize',10,'LineWidth',1.5);
%         plot(MicCenters(:,1),MicCenters(:,2),'y+','MarkerSize',6);
%         plot(CornerPts(:,1),CornerPts(:,2),'mx','MarkerSize',6);
%         plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',5);
%         legend({'O','centers','old','new'},'Location','bestoutside');
%         hold off;
%     end
% end


% %% ===== 消融实验5：去掉s和Δ（恒等映射，等价于不调用TriangleScaling） =====
% function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
%     % 消融实验5：完全不校正，输出=输入（基线对照）
%     % 等价于在 DetectCornersOurs.m 中注释掉 TriangleScaling 调用
%     if nargin<5, debug=false; end
%     CornerPts_new = CornerPts;
%     s_cluster = NaN;
%     dO = [0,0];
% 
%     if debug
%         O = Omega(1:2);
%         figure; hold on; axis equal ij;
%         title('Ablation-5: Identity (no scaling, no shift)');
%         plot(O(1),O(2),'g+','MarkerSize',10);
%         plot(MicCenters(:,1),MicCenters(:,2),'y+');
%         plot(CornerPts(:,1),CornerPts(:,2),'mx');
%         legend({'O','centers','corners (unchanged)'},'Location','bestoutside');
%         hold off;
%     end
% end


%% ===== 消融实验6：加权版本 =====
%% 注：此实验代码即下方的原加权版函数（边缘抑制 + 几何散布权重）
%% 使用时取消注释原有加权版代码块即可

%% 加权重
function [CornerPts_new, s_cluster, dO] = TriangleScaling(Omega, MicCenters, CornerPts, LensClass, debug)
    % 加权版：根据散布(几何)与边缘位置给点加权，做加权闭式解
    if nargin<5, debug=false; end
    O   = Omega(1:2);  O = O(:)';    % 圆心
    epsDen = 1e-9;
    minAngleDeg = 10; maxAngleDeg = 170;

    CornerPts_new = CornerPts; s_cluster = NaN; dO = [0,0];

    % 参与范围：坐标有效
    idxValid = all(isfinite(MicCenters),2) & all(isfinite(CornerPts),2);
    if nnz(idxValid) < 2, return; end
    M_all = MicCenters(idxValid,:); P_all = CornerPts(idxValid,:);

    % 先按角度筛三角 (O,Mi,Mj)，只用涉及这些三角的点
    DT    = delaunayTriangulation(M_all(:,1), M_all(:,2));
    pairs = edges(DT);
    if isempty(pairs), return; end
    keep = false(size(pairs,1),1);
    for r = 1:size(pairs,1)
        i = pairs(r,1); j = pairs(r,2);
        keep(r) = triAllAnglesOK(O, M_all(i,:), M_all(j,:), minAngleDeg, maxAngleDeg);
    end
    pairs_used = pairs(keep,:);
    if isempty(pairs_used), return; end
    usedIdx_local = unique(pairs_used(:));
    M = M_all(usedIdx_local,:);  P = P_all(usedIdx_local,:);
    Nv = size(M,1);

    % ---------- 权重设计 ----------
    % (1) 边缘抑制（半径稳健权重）
    r  = sqrt(sum((M - O).^2, 2));
    rmed = median(r);
    mad  = median(abs(r - rmed));
    if mad < 1e-6, mad = 1; end
    q = (r - rmed) ./ (2*mad);          % 以中位数为中心的稳健尺度
    w_edge = 1 ./ (1 + q.^2);           % Cauchy 样式，边缘权重下降
    % 想更激进可用 Tukey: w_edge = max(0, (1 - q.^2)).^2;

    % (2) 几何散布权重（角度更正交的点权重大）
    % 为每条参与边 (i,j)，在圆心 O 处计算 θ_O，令 w_pair = sin^2 θ_O，
    % 再把 w_pair 累加到端点 i、j 上。
    toLocal = -ones(size(M_all,1),1);
    toLocal(usedIdx_local) = 1:Nv;
    w_geom = eps*ones(Nv,1);            % 避免全 0
    for rEdge = 1:size(pairs_used,1)
        i_all = pairs_used(rEdge,1); j_all = pairs_used(rEdge,2);
        ii = toLocal(i_all); jj = toLocal(j_all);
        if ii<1 || jj<1, continue; end
        v1 = M(ii,:) - O;  v2 = M(jj,:) - O;
        n1 = norm(v1); n2 = norm(v2);
        if n1<1e-9 || n2<1e-9, continue; end
        c  = max(min(dot(v1,v2)/(n1*n2),1),-1);   % cos θ_O
        w_pair = 1 - c*c;                         % = sin^2 θ_O
        w_geom(ii) = w_geom(ii) + w_pair/2;
        w_geom(jj) = w_geom(jj) + w_pair/2;
    end
    % 归一（保持量纲适中）
    w_geom = w_geom / median(w_geom);

    % (3) 合成总权重
    w = w_edge .* w_geom;
    % 可选：再按半径衰减边缘（轻微）： w = w .* (rmed ./ max(rmed, r));
    % 正规化
    w = w / mean(w);
    w(~isfinite(w)) = 1;

    % ---------- 加权闭式解 ----------
    A = M - O;           % a_v
    C = O - P;           % c_v
    sw = sum(w);
    Abar = (w' * A) / sw;                  % 1x2
    Cbar = (w' * C) / sw;                  % 1x2
    Atil = A - Abar;                       % Nv x 2
    Ctil = C - Cbar;                       % Nv x 2

    num = sum( w .* sum(Atil .* Ctil, 2) );        % Σ w · <Â,Ĉ>
    den = sum( w .* sum(Atil.^2, 2) );             % Σ w · ||Â||^2
    if den < epsDen, return; end
    s = - num / den;

    if abs(1 - s) < 1e-3
        Delta = [0,0];
    else
        Delta = - (s*Abar + Cbar) / (1 - s);       % 1x2
    end
    O2 = O + Delta;

    % 更新“参与三角”的角点
    P_new_local = O2 + s * (M - O2);
    CornerPts_new(idxValid, :) = CornerPts(idxValid, :);
    tmp = CornerPts_new(idxValid, :);
    tmp(usedIdx_local, :) = P_new_local;
    CornerPts_new(idxValid, :) = tmp;

    s_cluster = s;
    dO = Delta;

    if debug
        figure; hold on; axis equal ij;
        title(sprintf('Weighted joint single-s (s=%.4f), dO=[%.3f,%.3f]', s, dO(1), dO(2)));
        plot(O(1),O(2),'c+','LineWidth',1.2,'MarkerSize',9);
        plot(O2(1),O2(2),'g+','LineWidth',1.5,'MarkerSize',10);
        scatter(M(:,1), M(:,2), 16, w, 'filled');   % 颜色看权重
        plot(CornerPts(:,1),  CornerPts(:,2),  'mx', 'MarkerSize', 6, 'LineWidth', 1.0);
        plot(CornerPts_new(:,1),CornerPts_new(:,2),'go','MarkerSize',4,'LineWidth',1);
        % 画参与三角
        for rEdge = 1:size(pairs_used,1)
            i_all = pairs_used(rEdge,1); j_all = pairs_used(rEdge,2);
            ii = toLocal(i_all); jj = toLocal(j_all);
            if ii<1 || jj<1, continue; end
            mi = M(ii,:); mj = M(jj,:);
            plot([mi(1) mj(1)], [mi(2) mj(2)], 'Color',[1 .6 0], 'LineWidth', 0.9);
            plot([O2(1) mi(1)], [O2(2) mi(2)], 'Color',[0 .5 1], 'LineStyle','-', 'LineWidth', 0.8);
            plot([O2(1) mj(1)], [O2(2) mj(2)], 'Color',[0 .5 1], 'LineStyle','-', 'LineWidth', 0.8);
        end
        colorbar; colormap parula; legend({'O','O2','M (weight)','corners old','corners new'}, 'Location','bestoutside');
        hold off;
    end
end


% --- 角度检查辅助 ---
function ok = triAllAnglesOK(O, Mi, Mj, minDeg, maxDeg)
    ok = angleOK(Mi - O,  Mj - O,  minDeg, maxDeg) && ...
         angleOK(O  - Mi, Mj - Mi, minDeg, maxDeg) && ...
         angleOK(O  - Mj, Mi - Mj, minDeg, maxDeg);
end
function tf = angleOK(v1, v2, minDeg, maxDeg)
    n1 = norm(v1); n2 = norm(v2);
    if n1 < 1e-12 || n2 < 1e-12, tf = false; return; end
    c = max(min(dot(v1,v2)/(n1*n2),1),-1);
    ang = acosd(c);
    tf = (ang >= minDeg) && (ang <= maxDeg);
end
