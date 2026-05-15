d=obj.dem;
sId=d.GROUP.sample;
%outside elements
[a1,r1]=cart2pol(obj.aX(sId)-d.SET.sampleW/2,obj.aY(sId)-d.SET.sampleW/2);
sideFilter=r1>d.SET.sampleW/2;

zFilter1=obj.aZ(sId)<0;
zFilter2=obj.aZ(sId)>d.SET.sampleH;
%velocity
[a2,r2]=cart2pol(obj.mVX(sideFilter),obj.mVY(sideFilter));
[vx,vy]=pol2cart(a1(sideFilter),-r2);
obj.mVX(sideFilter)=vx;
obj.mVY(sideFilter)=vy;

obj.mVZ(zFilter1)=abs(obj.mVZ(zFilter1));
obj.mVZ(zFilter2)=-abs(obj.mVZ(zFilter2));
%coordinate
[x,y]=pol2cart(a1(sideFilter),r1(sideFilter)*0+d.SET.sampleW/2);
obj.aX(sideFilter)=x+d.SET.sampleW/2;
obj.aY(sideFilter)=y+d.SET.sampleW/2;

obj.aZ(zFilter1)=0;
obj.aZ(zFilter2)=d.SET.sampleH;
