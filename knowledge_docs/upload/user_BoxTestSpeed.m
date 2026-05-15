clear;
M=fs.getMatDEMscore();
reportStr=['Your MatDEM score is ' num2str(M.MatDEMscore,4)];

if M.MatDEMscore<10
    speedStr='The computing speed is very slow';
elseif M.MatDEMscore<30
    speedStr='The computing speed is OK';
elseif M.MatDEMscore<70
    speedStr='The computing speed is good';
elseif M.MatDEMscore<150
    speedStr='The computing speed is very good';
else
    speedStr='The computing speed is perfect';
end
reportStr=[reportStr newline speedStr];

if M.isGPU==0
    reportStr=[reportStr newline 'A GPU may increase the computing speed dramatically'];
end
msgbox(reportStr);