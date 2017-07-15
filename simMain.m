%%������ΪGPS+INS��MAV�����ϵ��ں������򣬲��õ��Ǽ�ӿ������˲�
%%���йߵ���������״̬Ԥ�⣬GPS�����˲������������ⷽ����ֻ��GPS���������ߵ�����ֱֵ������״̬Ԥ�ⷽ���У�
%%ʹ��״̬Ԥ�ⷽ�̼��ߵ�����ֵ����״̬Ԥ�⣬���ƫ��״̬Ԥ�ⷽ�̵��й�ϵ��
%%ÿ��ʹ��ƫ��״̬Ԥ�ⷽ��Ԥ��õ�ƫ������GPS����ֵ�������������£�����״̬����ƫ�����
%%û��GPS����ֵ����û��������£�Ҳû��״̬ƫ��������뵱��û�н����˲�  

%%�ο����ף�
%%[1]Monocular Vision for Long-term Micro Aerial State Estimation:A
%%Compendium, Stephan Weiss,2013
%%[2]���������˲�����ϵ���ԭ������Ԫ��P49���õ�����ɢϵͳ����������㹫ʽ
%%[3]��Indirect Kalman Filter for 3D Attitude Estimation, Trawny, 2005 
%%2015/12/30��Matlab2014b
%%*****************************************************************************************************%%

clear;clc;
% global attiCalculator;
attiCalculator = AttitudeBase();
step = 0.01;
start_time = 0;
end_time = 50;
tspan = [start_time:step:end_time]';
N = length(tspan);
Ar = 10;
r = [Ar*sin(tspan) Ar*cos(tspan) 0.5*tspan.*tspan];         %����ʵ��켣����
v = [Ar*cos(tspan) -Ar*sin(tspan) tspan];
acc_inertial = [-Ar*sin(tspan) -Ar*cos(tspan) ones(N,1)];


atti = [0.1*sin(tspan) 0.1*sin(tspan) 0.1*sin(tspan)];
Datti = [0.1*cos(tspan) 0.1*cos(tspan) 0.1*cos(tspan)];
g = [0 0 -9.8]';
gyro_pure = zeros(N,3);
acc_pure = zeros(N,3);
gps_pure= r;



a = wgn(N,1,1)/5;
b = zeros(N,1);
b(1) = a(1)*step;
%������������imu����
for iter = 1:N
    A = attiCalculator.Datti2w(atti(iter,:));
    gyro_pure(iter,:) = Datti(iter,:)*A';
    cnb = attiCalculator.a2cnb(atti(iter,:));
    acc_pure(iter,:) = cnb*(acc_inertial(iter,:)' - g);
%     acc_pure(iter,:) = cnb*(acc_inertial(iter,:)');
end
% state0 = zeros(10,1);
% state0(7) = 1;

%���ٶȼƺ������Ǽ�����
acc_noise = acc_pure + randn(N,3)/10;           %���ɹߵ���GPS����ֵ��ͬʱ��������
gyro_noise = gyro_pure + randn(N,3)/10;
gps_noise=[zeros(N,1) gps_pure+randn(N,3)/10];
for i=1:10:N
    gps_noise(i,1)=1;
end
% acc_noise = acc_pure ;
% gyro_noise = gyro_pure;
state0 = zeros(16,1);
state0(2) = 10;
state0(4) = 10;
state0(7) = 1;

errorstate0=zeros(15,1);%����ʼ״̬��ֵ
Cov=[0.01*ones(3,1);zeros(3,1);0.01*ones(3,1);zeros(3,1)];
Qc0=diag(Cov);%��ʼ��������
Rc0=diag([0.01,0.01,0.01]);%GPS������������
% Qc0=diag(zeros(12,1));%��ʼ��������
% Rc0=diag(zeros(3,1));%GPS������������

%���Ըı���ʹ����Ĺ���Ԫ�������ݴ��������߲���
ins = InsSolver(Qc0,Rc0);
% [state,errorstate] = ins.imu2state(acc_pure,gyro_pure,gps_pure,state0,errorstate0,tspan,step,0);
[state,errorstate] = ins.imu2state(acc_noise,gyro_noise,gps_noise,state0,errorstate0,tspan,step,0);
%plot trajactory
figure(4)
plot3(r(:,1),r(:,2),r(:,3));
title('��ʵ�켣');
grid on;
figure(1);
plot3(state(:,1),state(:,2),state(:,3));
title('�˲��켣');
grid on;

% plot postion error
figure(2),subplot(1,3,1);
plot(tspan,state(:,1) - r(:,1));
grid on;
subplot(1,3,2);
plot(tspan,state(:,2) - r(:,2));
grid on;
subplot(1,3,3);
plot(tspan,state(:,3) - r(:,3));
grid on;

%convert quat to attitue angle
% fprintf('press any key to continue\n');
% pause(5);
newatti = zeros(N,3);

for i = 1:N
   newatti(i,:) = attiCalculator.cnb2atti(attiCalculator.quat2cnb(state(i,7:10)));
end

%plot attitute error
figure(3),subplot(1,3,1);
title('attitute angle error');
plot(tspan,newatti(:,1) - atti(:,1));
grid on;
subplot(1,3,2);
plot(tspan,newatti(:,2) - atti(:,2));
grid on;
subplot(1,3,3);
plot(tspan,newatti(:,3) - atti(:,3));
grid on;

