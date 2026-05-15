load('TempModel\3DJointStress2.mat')%import a .mat file first
%show connections, details in the help .xls
d.showFilter('Group',{'sample'});%only shown the connections of sample
figure;
d.showC();%show the connections (tube)

figure;
d.showC();%show the connections (tube)
mfs.colormap('red');

return
figure;
subplot(1,2,1);
d.showC('nFnX');%show the nFnX
subplot(1,2,2);
d.showC('bFilter');