function layer1=layeredball(class,rate,Hight)
%W L H num_j porosity 
%1 0
%2 0.2
%3 0.6
%4 1
data = csvread(class);
num_j = data(1,4);
resolution = rate;

porosity = data(1,5);
W = data(1,1);
L = data(1,2);
H = data(1,3);
H1 = H;
num_ball_total=0;
layerHight = Hight;
num_layer = ceil(H/layerHight);
H = num_layer*layerHight;

for i = 2:2:num_j+1
    r_min = data(i,1) * 0.5 * resolution;
    r_max = data(i+1,1) * 0.5 * resolution;
    volumefraction = data(i+1,2) - data(i,2);
    v_ball = volumefraction * (1 - porosity) * W * layerHight;
    num_ball_total = num_ball_total + round(v_ball / ( pi * ((r_max + r_min) * 0.5)^2));
end
inf_ball = zeros(num_ball_total*num_layer,4);

for k = 1:num_layer
    rng(k);
    num_ball0=0;
    R_ball = zeros(num_ball_total,1);
    X_ballPos = zeros(num_ball_total,1);
    Y_ballPos = zeros(num_ball_total,1);
    Z_ballPos = zeros(num_ball_total,1);
    for i = 2:2:num_j+1
        r_min = data(i,1) * 0.5 * resolution;
        r_max = data(i+1,1) * 0.5 * resolution;
        volumefraction = data(i+1,2) - data(i,2);
        v_ball = volumefraction * (1 - porosity) * W * layerHight;
        num_ball = round(v_ball / ( pi * ((r_max + r_min) * 0.5)^2));
        x = zeros(num_ball,1);
        y = zeros(num_ball,1);
        r = rand(num_ball,1) .* (r_max - r_min) + r_min;
        for j =1:num_ball
            Rball = r(1);
            x_min = Rball;
            x_max = W - Rball;
            y_min = layerHight*(k-1)+Rball;
            y_max = layerHight*(k) - Rball;
            Xball = x_min+rand(1)*(x_max-x_min);
            Yball = y_min+rand(1)*(y_max-y_min);
            x(j) = Xball;
            y(j) = Yball;
        end
        X_ballPos(num_ball0+1:num_ball0+num_ball) = x;
        Y_ballPos(num_ball0+1:num_ball0+num_ball) = y;
        R_ball(num_ball0+1:num_ball0+num_ball) = r;
        num_ball0 = num_ball0 + num_ball;
    end
    inf_ball((1+num_ball_total*(k-1)):(num_ball_total*k),:) = [R_ball,X_ballPos,Z_ballPos,Y_ballPos];
end
layer1.X=inf_ball(1:end,2);
layer1.Y=inf_ball(1:end,3);
layer1.Z=inf_ball(1:end,4);
layer1.R=inf_ball(1:end,1);
end


                                                                                                    

