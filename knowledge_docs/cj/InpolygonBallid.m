function filterballid = InpolygonBallid(d,directions,gName,varargin)
%UNTITLED 得到一个多边形切割出来的颗粒Id
%   此处显示详细说明
point = [];
for i=1:length(directions)
    direction=directions(i);
    dirName=['a' direction];
    point(:,i) = d.mo.(dirName)(d.GROUP.(gName));
end
xv = varargin(1,:);
yv = varargin(2,:);
xq = point(:,1);
yq = point(:,2);
filterIn = inpolygon(xq, yq, xv, yv);
filterballid = find(filterIn);
end