% Copyright 2012. All rights reserved.
% Author: Andreas Geiger
%         Institute of Measurement and Control Systems (MRT)
%         Karlsruhe Institute of Technology (KIT), Germany

% This is free software; you can redistribute it and/or modify it under the
% terms of the GNU General Public License as published by the Free Software
% Foundation; either version 3 of the License, or any later version.

% This software is distributed in the hope that it will be useful, but WITHOUT ANY
% WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
% PARTICULAR PURPOSE. See the GNU General Public License for more details.

% You should have received a copy of the GNU General Public License along with
% this software; if not, write to the Free Software Foundation, Inc., 51 Franklin
% Street, Fifth Floor, Boston, MA 02110-1301, USA 

function corners = findCornersOrigin(img,tau,refine_corners)

% 输入：
% img → 输入图像（棋盘格图片）
% tau → 打分阈值，用来过滤低质量角点
% refine_corners → 是否做亚像素细化（1=细化，0=不细化）
% 
% 输出：
% corners 结构体，包含角点位置 p、局部方向 v1,v2、打分 score 等。

% convert to double grayscale image，转换灰度，归一化
img = im2double(img);
if length(size(img))==3
  img = rgb2gray(img);
end

% 3 scales，定义半径
radius(1) = 4;
radius(2) = 8;
radius(3) = 12;

% sobel masks
du = [-1 0 1; -1 0 1; -1 0 1];
dv = du';

% compute image derivatives (for principal axes estimation)，计算图像导数（用于主轴估计）
img_du     = conv2(double(img),du,'same');
img_dv     = conv2(double(img),dv,'same');
img_angle  = atan2(img_dv,img_du);
img_weight = sqrt(img_du.^2+img_dv.^2);

% correct angle to lie in between [0,pi]，归一化角度到 [0,π]
img_angle(img_angle<0)  = img_angle(img_angle<0)+pi;
img_angle(img_angle>pi) = img_angle(img_angle>pi)-pi;

% scale input image，图像强度归一化
img     = double(img);
img_min = min(img(:));
img_max = max(img(:));
img     = (img-img_min)/(img_max-img_min);

% template properties，定义模板参数
template_props = [0 pi/2 radius(1); pi/4 -pi/4 radius(1); 0 pi/2 radius(2); pi/4 -pi/4 radius(2); 0 pi/2 radius(3); pi/4 -pi/4 radius(3)];
%template_props = [0 pi/2 radius(1); pi/4 -pi/4 radius(1); 0 pi/2 radius(2); pi/4 -pi/4 radius(2)];
disp('Filtering ...');

% filter image，模板匹配
img_corners = zeros(size(img,1),size(img,2));
for template_class=1:size(template_props,1)
  
  % create correlation template，创建关联模板
  template = createCorrelationPatch(template_props(template_class,1),template_props(template_class,2),template_props(template_class,3));
  
  % filter image according with current template，根据当前模板过滤图像
  img_corners_a1 = conv2(img,template.a1,'same');
  img_corners_a2 = conv2(img,template.a2,'same');
  img_corners_b1 = conv2(img,template.b1,'same');
  img_corners_b2 = conv2(img,template.b2,'same');
  
  % compute mean，计算均值
  img_corners_mu = (img_corners_a1+img_corners_a2+img_corners_b1+img_corners_b2)/4;
  
  % case 1: a=white, b=black
  img_corners_a = min(img_corners_a1-img_corners_mu,img_corners_a2-img_corners_mu);
  img_corners_b = min(img_corners_mu-img_corners_b1,img_corners_mu-img_corners_b2);
  img_corners_1 = min(img_corners_a,img_corners_b);
  
  % case 2: b=white, a=black
  img_corners_a = min(img_corners_mu-img_corners_a1,img_corners_mu-img_corners_a2);
  img_corners_b = min(img_corners_b1-img_corners_mu,img_corners_b2-img_corners_mu);
  img_corners_2 = min(img_corners_a,img_corners_b);
  
  % update corner map
  img_corners = max(img_corners,img_corners_1);
  img_corners = max(img_corners,img_corners_2);
end

% extract corner candidates via non maximum suppression，通过非最大抑制提取角候选
corners.p = nonMaximumSuppression(img_corners,3,0.025,0); % margin=5 /0
disp('Refining ...');

% subpixel refinement，亚像素细化（可选）
if refine_corners
  corners = refineCornersOrigin(img_du,img_dv,img_angle,img_weight,corners,10);
end

% remove corners without edges，删除无边缘角点
idx = corners.v1(:,1)==0 & corners.v1(:,2)==0;
corners.p(idx,:)  = [];
corners.v1(idx,:) = [];
corners.v2(idx,:) = [];

disp('Scoring ...');

% score corners，打分
corners = scoreCorners(img,img_angle,img_weight,corners,radius);

% remove low scoring corners，移除低分角点
idx = corners.score<tau;
corners.p(idx,:)     = [];
corners.v1(idx,:)    = [];
corners.v2(idx,:)    = [];
corners.score(idx) = [];

% make v1(:,1)+v1(:,2) positive (=> comparable to c++ code)
idx = corners.v1(:,1)+corners.v1(:,2)<0;
corners.v1(idx,:) = -corners.v1(idx,:);

% make all coordinate systems right-handed (reduces matching ambiguitie from 8 to 4)，坐标系调整
corners_n1 = [corners.v1(:,2) -corners.v1(:,1)];
flip       = -sign(corners_n1(:,1).*corners.v2(:,1)+corners_n1(:,2).*corners.v2(:,2));
corners.v2 = corners.v2.*(flip*ones(1,2));

% convert to 0-based index
corners.p = corners.p-1;
