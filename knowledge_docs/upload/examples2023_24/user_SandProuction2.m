clear;
load('TempModel\SandProduction1.mat');
%-----------initializing the model
B.setUIoutput();
d=B.d;	
d.calculateData();
d.mo.setGPU('off');
d.getModel();
d.resetStatus();

% % assign material
% matTxt=load('Mats\Sandstone.txt');
% Mats{1,1}=material('Sandstone',matTxt,B.ballR);
% Mats{1,1}.Id=1;
% d.Mats=Mats;
% d.groupMat2Model({'sample'},1);

% coarseId=d.GROUP.Coarse;
% fineId=d.GROUP.Fine;
% d.addFixId('X',coarseId);
% d.addFixId('Y',coarseId);
% d.addFixId('Z',coarseId);
% d.balance('Standard');


% initialize
p=pore3d(d,'Coarse');
% p=build2pore(d,'Coarse');
p.setInitialPores();
p.isCouple= 0;
p.fKFlow(:)=1e-7;
p.pPressure= (p.Fluids.refP)*ones(size(p.pPressure)); 
% set boundary
refP=p.Fluids.refP;
topPId= find(p.pZ>0.9*(max(p.pZ)-min(p.pZ))+min(p.pZ));
botPId= find(p.pZ<0.1*(max(p.pZ)-min(p.pZ))+min(p.pZ));
botPre=refP+2e6*9.8;
topPre=refP-2e6*9.8;

% circle pre
steps=500;
d.mo.setGPU('on');
p.setGPU('on');
d.showB= 0;p.dT=d.mo.dT*20;Q=[];
while 1
    for jj=1:steps
        p.pPressure(botPId)=botPre;
        p.pPressure(topPId)=topPre;
        p.setPressure();
        p.balance();
    end
    assert(~any(isnan(gather(p.pPressure))),'boom shakalaka!!!!');%check if correct
    poreFlowMass=p.fFlowMass(p.poreFacetIdx);
    Qout=gather(sum(poreFlowMass(botPId,:),'all'));
    Q=[Q;Qout];
    Qinner=gather(sum(poreFlowMass(topPId,:),'all'));
    Qpercent= -Qout/Qinner*100;
    fs.disp(['Balance Rate: ',num2str(Qpercent),' percent']);
    if abs(Qpercent-100)<10e-3
        break;
    end
end


d.mo.setGPU('off');
p.setGPU('off');
d.clearData(1);%clear dependent data
d.recordCalHour('Step1Finish');
save(['TempModel/' B.name '2.mat'],'B','d','p');
d.calculateData();%because data is clear, it will be re-calculated