function mSurfaceFilter=getSurfaceFilter(B,dh)
d=B.d;
%1.get surface1 (x,z)
dx=2*B.ballR;
xa=floor(d.mo.aX(1:d.mNum)./dx)+1;
% Adjust xa to be positive indices starting from 1
minXa = min(xa);
xa = xa - minXa + 1;
xi = ((0.5:max(xa))' + minXa - 1) * dx;
zi=accumarray(gather(xa),gather(d.mo.aZ(1:d.mNum)),[max(xa),1],@(x)max(x));

%2.get surface2 (x2,z2), move dh from surface1
gx=xi(3:end)-xi(1:end-2);
gx=gx([1,1:end,end]);
gz=zi(3:end)-zi(1:end-2);
gz=gz([1,1:end,end]);

gd=sqrt(gx.^2+gz.^2);
gx=gx./gd;gz=gz./gd;

x2=xi+dh*gz;
z2=zi-dh*gx;
z2=max(z2,0);

[x2,I]=sort(x2);
z2=z2(I);
%3.get surface element filter
FH2=griddedInterpolant(x2,z2);
mSurfaceFilter=(FH2(gather(d.mo.aX)))<d.mo.aZ;

% hold on
% plot3(xi,zi*0,zi+B.ballR,'r','LineWidth',1.5)
% plot3(x2,z2*0,z2+B.ballR,'g','LineWidth',1.5)
end
