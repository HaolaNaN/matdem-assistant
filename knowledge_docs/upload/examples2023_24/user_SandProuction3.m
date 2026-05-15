clear;
load('TempModel\SandProduction2.mat');
%-----------initializing the model
B.setUIoutput();
d=B.d;	
d.calculateData();
d.mo.setGPU('off');
d.getModel();
d.resetStatus();

% set showfilter
showFilter= d.mo.aZ>0;
filter=abs(d.mo.aZ-0.025)<0.005|abs(d.mo.aZ-0.05)<0.005;
showFilter(end)=false;
showFilter(d.GROUP.wall0)= false;
showFilter(d.GROUP.Fine)=true;
showFilter(filter)= false;
showFilter(d.GROUP.wallTop)= true;
% initialize

% set boundary
refP=p.Fluids.refP;
botPId= find(p.pZ>0.9*(max(p.pZ)-min(p.pZ))+min(p.pZ));
topPId= find(p.pZ<0.1*(max(p.pZ)-min(p.pZ))+min(p.pZ));
botPre=refP+2e3*0.98;
topPre=refP-2e3*0.98;

% circle pre
totalCircle= 500;
steps=500;
d.tic(totalCircle);
d.mo.setGPU('on');
p.setGPU('on');
d.showB= 1;
d.addFixId('X',d.GROUP.Coarse);
d.addFixId('Y',d.GROUP.Coarse);
d.addFixId('Z',d.GROUP.Coarse);
d.mo.aR(d.GROUP.wallTop)= d.mo.aR(d.GROUP.wallTop)/sqrt(2);
d.moveGroup('topB',0,0,5*d.SET.wallR);
d.mo.mVis(:)= 0;
d.mo.mGZ(:)= 0;
p.isCouple= 1;
p.dT=d.mo.dT;
[maxValue, index] = max(d.mo.aZ(d.GROUP.Fine));Acc=[];%test
for ii=1:totalCircle
    for jj=1:steps
        p.pPressure(botPId)=botPre;
        p.pPressure(topPId)=topPre;
        p.setPressure();
        p.balance();
        d.balance();
    end
    d.figureNumber=1;
    d.showFilter('Filter',showFilter);
    d.show('Displacement');
    caxis([0 0.025]);
    view([38.1144 8.5500]);
    frames(ii)=getframe();
    d.toc();
end

fs.movie2gif([B.name,char(datetime('now'), 'yyyyMMddHHmm'),'.gif'],frames,0.3);
d.mo.setGPU('off');
p.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '3.mat'],'B','d');
d.calculateData();%because data is clear, it will be re-calculated