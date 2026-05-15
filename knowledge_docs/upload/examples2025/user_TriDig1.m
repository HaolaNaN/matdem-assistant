clear;fs.randSeed(1);%change number to get different random model
%---------------------define parameters----------------------
ballRSample=0.1;%0.1 big ball, 0.03 small ball
bowlH=2;bowlR=2;
frame=[-bowlR,-bowlR,0,bowlR,bowlR,bowlH];
%---------------------end define parameters----------------------
%----------make a Box, and pack balls---------
B=obj_Box('TriDig');%declare a box object
B.ballR=ballRSample;%element radius
B.setFrame(frame);
B.setType('topPlaten');
B.buildInitialModel();
B.SET.bowlR=bowlR;%record the bowl size
B.SET.bowlH=bowlH;

d=B.d;
B.gravitySediment();
%----------end make a Box, and pack balls---------
fs.saveData(B,1);%as the data in the folder TempModel