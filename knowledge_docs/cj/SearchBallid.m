function filterballid = SearchBallid(d,gName,varargin)
%Obtain the IDs of group 2 particles within a certain range of the boundary of group 1.
%20260406byCJ
d.mo.zeroBalance();
% 球心距
xx = d.mo.nBall;
xx(~ismember(xx, d.GROUP.(gName))) = 0;
xx(ismember(xx, d.GROUP.(gName))) = 1;
xx = xx.*d.mo.cFilter;

disR=sqrt((d.mo.aX(d.mo.nBall)-d.mo.aX(1:d.mNum)).^2+(d.mo.aY(d.mo.nBall)-d.mo.aY(1:d.mNum)).^2+(d.mo.aZ(d.mo.nBall)-d.mo.aZ(1:d.mNum)).^2)-varargin;
disR = disR.*xx;
filterballid = find(any(disR < 0, 2) & any(disR ~= 0, 2));
d.delElement(filterballid);
end