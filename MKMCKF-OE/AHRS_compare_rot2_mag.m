function AHRS_compare_rot2_mag()

%%
% This function is used to compare the performance of orientation
% estimation using ESKF, GD, and MKMCKF-OE.
%
% The raw data is sampled at gait frequency f=0.2hz with 
% magnetic disturbance.
%%

clear all
%% add path
addpath('MKMCKF-OE');
addpath('ESKF');
addpath('madgwick_algorithm_matlab');
addpath('data');

%% load the data
load('gait_0.2_mag.mat');
IMU=gait_02_mag;
enc=load('enc_gait_0.2_magd.mat');

%
Accelerometer=IMU.Acceleration;
Accelerometer=-Accelerometer;
Gyroscope=IMU.Gyroscope;
fs=IMU.fs;
Magnetic=IMU.Magnetic;
Magnetic=100*Magnetic;

len=length(Accelerometer);
% 
for i=1:len
Accelerometer_norm(i)= norm(Accelerometer(i,:)); 
Magnetic_norm(i)= norm(Magnetic(i,:)); 
end

% plot the raw data
t=0:1/fs:1/fs*(length(Accelerometer)-1);
time=[t;t;t];
time=time';
figure
x1=subplot(3,1,1);
plot(time,Accelerometer)
legend('acc')
set(gca,'FontSize',16)
x2=subplot(3,1,2);
plot(time,Gyroscope)
legend('gyro')
set(gca,'FontSize',16)
x3=subplot(3,1,3);
plot(time,Magnetic)
legend('mag')
set(gca,'FontSize',16)
linkaxes([x1,x2,x3],'x')


%% GD method

AHRS = MadgwickAHRS('SamplePeriod', 1/fs, 'Beta', 0.1);

time=0:1/fs:1/fs*(len-1);
quat = zeros(length(time), 4);
for t = 1:length(time)
    AHRS.Update(Gyroscope(t,:), Accelerometer(t,:), Magnetic(t,:));	% gyroscope units must be radians
    quat(t, :) = AHRS.Quaternion;
end

% Plot algorithm output as Euler angles
for i=1:length(quat)
Quat(i)=quaternion(quat(i,1),quat(i,2),quat(i,3),quat(i,4));
end

euler=eulerd(Quat,'ZXY','frame');



%% ahrs
ahrs=orientation_estimation_ahrs_fun(Accelerometer,Gyroscope,Magnetic,fs);
euler_ahrs=eulerd(ahrs.Quat,'ZXY','frame');


% len=length(Magnetic);
% Mag_norm=zeros(len,1);
% for i=1:len
%     Mag_norm(i)=norm(Magnetic(i,:));
% end
% figure
% plot(Mag_norm)
%% mkmc ahrs
sigma_1=2.01;
sigma_2=0.1351;
sigma1=2*sigma_1*sigma_1;
sigma2=2*sigma_2*sigma_2;
xigma_x=[10^8 10^8 10^8 10^8 10^8 10^8 sigma1 sigma1 sigma1 sigma2 sigma2 sigma2]; 
xigma_y=[10^8 10^8 10^8 10^8 10^8 10^8];
mkmc_ahrs=orientation_estimation_ahrs_mkmc_fun_(Accelerometer,Gyroscope,Magnetic,fs,xigma_x,xigma_y);
euler_mkmc_ahrs=eulerd(mkmc_ahrs.Quat,'ZXY','frame');

figure
x1=subplot(3,1,1);
plot(time,euler(:,1),'blue',time,euler_ahrs(:,1),'red',time,euler_mkmc_ahrs(:,1),'black')
legend('GD Yaw','AHRS Yaw','MKMC Yaw')
set(gca,'FontSize',12)
x2=subplot(3,1,2);
plot(time,euler(:,2),'blue',time,euler_ahrs(:,2),'red',time,euler_mkmc_ahrs(:,2),'black')
legend('GD Roll','AHRS Roll','MKMC Roll')
set(gca,'FontSize',12)
x3=subplot(3,1,3);
plot(time,euler(:,3),'blue',time,euler_ahrs(:,3),'red',time,euler_mkmc_ahrs(:,3),'black')
legend('GD Pitch','AHRS Pitch','MKMC Pitch')
set(gca,'FontSize',12)
linkaxes([x1,x2,x3],'x')

%% 
t_s=30.910; COR=[54.44,0.9274,-91.82];
Ang.t=enc.gait(:,17)-enc.gait(1,17)+t_s;
Ang.ang=enc.gait(:,1)+enc.gait(:,2);
Ang.ang=-Ang.ang/pi*180;

figure
plot(Ang.t,Ang.ang+COR(2),'m',time,euler(:,2),'blue',time,euler_ahrs(:,2),'red',time,euler_mkmc_ahrs(:,2),'black')
legend('enc','gd','ahrs','mkmc')


% imu 
t_imu=0:0.001:time(end);
for k=1:3
euler_imu(:,k)=spline(time,euler(:,k),t_imu);
euler_ahrs_imu(:,k)=spline(time,euler_ahrs(:,k),t_imu);
euler_mkmc_ahrs_imu(:,k)=spline(time,euler_mkmc_ahrs(:,k),t_imu);
end
% time interval  [t_s, 30+t_s]
t_dur=30;
t_index_imu=find(t_imu>=Ang.t(1)&t_imu<(t_dur+t_s));
euler_imu_=euler_imu(t_index_imu,:);
euler_ahrs_imu_=euler_ahrs_imu(t_index_imu,:);
euler_mkmc_ahrs_imu_=euler_mkmc_ahrs_imu(t_index_imu,:);

% 
t_index_enc=find(Ang.t<t_dur+t_s);
angle=Ang.ang(t_index_enc);

euler_true=COR.*ones(size(euler_imu_));
euler_true(:,2)=euler_true(:,2)+angle;

error.t=t_imu(t_index_imu);
error.gd=euler_imu_-euler_true;
error.ahrs=euler_ahrs_imu_-euler_true;
error.mkmc=euler_mkmc_ahrs_imu_-euler_true;
error.true=euler_true;
error.cor=COR;
error.gd_rms=rms(error.gd);
error.ahrs_rms=rms(error.ahrs);
error.mkmc_rms=rms(error.mkmc);
error.sigma1=sigma1;
error.sigma2=sigma2;




end