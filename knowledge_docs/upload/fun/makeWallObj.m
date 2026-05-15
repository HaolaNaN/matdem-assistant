function P=CreateWallObj(SET,r,h)%var包不包括第一个点
    P.X=[];P.Y=[];P.Z=[];P.R=[];
    r1=SET.r1;r2=SET.r2;x0=SET.x0;y0=SET.y0;
  %------------left boudary------
    x1=0;x2=x0-r2/2;
    y1=(r1-r2)*sqrt(3)/2;y2=0;

    l= sqrt((x1-x2)^2+(y1-y2)^2);
    num1= ceil(l/(sqrt(2)*r));
    if x1~=x2
        x= x1:(x2-x1)/num1:x2;x=x(1:end-1);
    elseif y1==y2
        warning('Check for repeating points ')
    else
        x= ones(1,num1)*x1;
    end
    if y1~=y2
        y= y1:(y2-y1)/num1:y2;y=y(1:end-1);
    else
        y= ones(1,num1)*y1;
    end
    num2= ceil(h/(sqrt(2)*r));
    z= 0:h/num2:h;z=z(2:end-1);
    P.X= [P.X;repmat(x',num2-1,1)];
    P.Y= [P.Y;repmat(y',num2-1,1)];
    P.Z= [P.Z;reshape(repmat(z',1,num1)',[],1)];
    P.R= [P.R;r*ones((num1)*(num2-1),1)];
%--------top boundary------
    l=pi/3*r1;
    num3= ceil(l/(sqrt(2)*r));
    x=[];y=[];
    for i=1:num3
        x=[x;x0+r1*cos(pi/3+pi/3*(i-1)/num3)];
        y=[y;y0+r1*sin(pi/3+pi/3*(i-1)/num3)];
    end
    P.X= [P.X;repmat(x,num2-1,1)];
    P.Y= [P.Y;repmat(y,num2-1,1)];
    P.Z= [P.Z;reshape(repmat(z',1,num3)',[],1)];
    P.R= [P.R;r*ones((num3)*(num2-1),1)];
%--------right boundary------
    x1=x0+r2/2;x2=2*x0;
    y1=0;y2=(r1-r2)*sqrt(3)/2;
    x=[];y=[];
    if x1~=x2
        x= x1:(x2-x1)/num1:x2;x=x(1:end-1);
    elseif y1==y2
        warning('Check for repeating points ')
    else
        x= ones(1,num1)*x1;
    end
    if y1~=y2
        y= y1:(y2-y1)/num1:y2;y=y(1:end-1);
    else
        y= ones(1,num1)*y1;
    end
    P.X= [P.X;repmat(x',num2-1,1)];
    P.Y= [P.Y;repmat(y',num2-1,1)];
    P.Z= [P.Z;reshape(repmat(z',1,num1)',[],1)];
    P.R= [P.R;r*ones((num1)*(num2-1),1)];
    %--------bot boundary------
    l=pi/3*r2;
    num3= ceil(l/(sqrt(2)*r));
    x=[];y=[];
    for i=1:num3
        x=[x;x0+r2*cos(2*pi/3-pi/3*(i-1)/num3)];
        y=[y;y0+r2*sin(2*pi/3-pi/3*(i-1)/num3)];
    end
    P.X= [P.X;repmat(x,num2-1,1)];
    P.Y= [P.Y;repmat(y,num2-1,1)];
    P.Z= [P.Z;reshape(repmat(z',1,num3)',[],1)];
    P.R= [P.R;r*ones((num3)*(num2-1),1)];

    %--------front boundary------
    a.X=[];a.Y=[];a.Z=[];a.R=[];
    for i=1:num1+1
        x=[];y=[];
        l=pi/3*(r2+(r1-r2)*(i-1)/num1);
        r0= r2+(r1-r2)*(i-1)/num1;
        num4= ceil(l/(sqrt(2)*r));
        for j=1:num4+1
            x=[x;x0+r0*cos(2*pi/3-pi/3*(j-1)/num4)];
            y=[y;y0+r0*sin(2*pi/3-pi/3*(j-1)/num4)];
        end
        P.X= [P.X;x];
        P.Y= [P.Y;y];
        P.Z= [P.Z;h*ones(num4+1,1)];
        P.R= [P.R;r*ones(num4+1,1)];

        a.X= [a.X;x];
        a.Y= [a.Y;y];
        a.Z= [a.Z;0*ones(num4+1,1)];
        a.R= [a.R;r*ones(num4+1,1)];

    end
    P.X= [P.X;a.X];
    P.Y= [P.Y;a.Y];
    P.Z= [P.Z;a.Z];
    P.R= [P.R;a.R];



    %--------back boundary------


end