clear
load('TempModel/TunnelLoad2D1.mat');
%------------initialize model-------------------
B.setUIoutput();
d=B.d;
d.calculateData();
d.mo.setGPU('off');
d.getModel();%get xyz from d.mo

objxz = readmatrix('slope/公路隧道断面.csv');
obj.X = objxz(:,1)*0.01;
obj.Y = zeros(length(objxz),1);
obj.Z = objxz(:,2)*0.01;
obj.R = zeros(length(objxz),1)+0.2;

obj=mfs.make3Dfrom2D(obj,3,B.ballR,'Y',0.8);%三维模型时使用

TunnelId=d.addElement(1,obj);%add a slope boundary
d.addGroup('Tunnel',TunnelId);%add a new group
d.setClump('Tunnel');%set the pile clump

quadCorners = [obj.X';obj.Z'];
ballid = f.run('fun/InpolygonBallid.m',d,'XZ','sample',quadCorners);
d.addGroup('hole',d.GROUP.sample(ballid));
d.delElement(d.GROUP.hole);

ballid = f.run('fun/SearchBallid.m',d,'Tunnel',5);

d.showB=1;
figure;
d.show('aR');

d.mo.setGPU('auto');
d.balance('Standard',1);%standard balance
%--------------------save data-----------------------
d.mo.setGPU('off');
d.clearData(1);
d.recordCalHour('BoxTunnel2Finish');
save(['TempModel/' B.name '2.mat'],'B','d');
save(['TempModel/' B.name '2R' num2str(B.ballR) '-distri' num2str(B.distriRate)  'aNum' num2str(d.aNum) '.mat']);
%--------------------end save data-----------------------

d.calculateData();
d.show('StressZZ');
d.show('mV');