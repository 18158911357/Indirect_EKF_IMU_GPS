%%������ΪGPS+INS��MAV�����ϵ��ںϳ���ߵ����㣨�˲��ںϣ����֣����õ��Ǽ�ӿ������˲�
%%���йߵ���������״̬Ԥ�⣬GPS�����˲������������ⷽ����ֻ��GPS���������ߵ�����ֱֵ������״̬Ԥ�ⷽ���У�
%%ʹ��״̬Ԥ�ⷽ�̼��ߵ�����ֵ����״̬Ԥ�⣬���ƫ��״̬Ԥ�ⷽ�̵��й�ϵ��
%%ÿ��ʹ��ƫ��״̬Ԥ�ⷽ��Ԥ��õ�ƫ������GPS����ֵ�������������£�����״̬����ƫ�����
%%û��GPS����ֵ����û��������£�Ҳû��״̬ƫ��������뵱��û�н����˲�  

%%�ο����ף�
%%[1]Monocular Vision for Long-term Micro Aerial State Estimation:A
%%Compendium, Stephan Weiss,2013
%%[2]���������˲�����ϵ���ԭ������Ԫ��P49���õ�����ɢϵͳ����������㹫ʽ
%%[3]��Indirect Kalman Filter for 3D Attitude Estimation, Trawny, 2005 
%%2015/12/30
%%*****************************************************************************************************%%

classdef InsSolver
    properties
        attiCalculator;
        Qc;
        Rc;
    end
    methods
        function o = InsSolver(Qc0,Rc0)
            o.attiCalculator = AttitudeBase();
            o.Qc=Qc0;
            o.Rc=Rc0;
        end
        
        
        function dy = imuDynamics( o,t,state,x )
            %��Ԫ����imu����ѧ����
            acc = x(1:3);
            gyro = x(4:6);
            v = state(4:6);
            quat = state(7:10);
            ba = state(11:13);
            bw = state(14:16);
            
%             na = zeros(3,1);
%             nw = zeros(3,1);
%             na = randn(3,1)*0.1;
%             nw = randn(3,1)*0.1;
            
            g = [0 0 -9.8]';
            cnb = o.attiCalculator.quat2cnb(quat);
            omega = o.attiCalculator.QuatMulitMati(quat,[0;gyro - bw]);
            dy = [v;cnb'*(acc - ba)+g;omega/2;zeros(6,1)];
            
        end
        
        function [state,predErrorState] = imu2state(o,acc_nose,gyro_noise,gps_noise,state0,errorstate0,tspan,step,isODE45)
            %acc��gyro�ֱ�Ϊ�ӱ�����������
            %state0��        ��ʼ״̬
            %errorstate0��   ƫ���ʼ״̬
            %Qc0��           ������
            %tspan��         ʱ��
            %step��          ����
            %isODE45��       ʹ��ODE45���ߵ�������
            if nargin < 9
                isODE45 = 1;
            end
            
            N = length(tspan);
            state = zeros(N,length(state0));
            predErrorState=zeros(N,length(errorstate0));
        
            predP=cell(N,1);    %ƫ��Ԥ������
            
            state(1,:) = state0';
            predErrorState(1,:)= errorstate0';
            predP{1}=zeros(15); %��ƫ��Ԥ������
            
            for i = 1:N - 1
                state(i+1,:) = o.statePrediction(state(i,:)',...
                                                [tspan(i) tspan(i+1)],...
                                                [acc_nose(i,:) gyro_noise(i,:)]',...
                                                isODE45)';
                                            
                predQ=o.QuatNormalize(state(i+1,7:10));         %��Ԫ����һ�������뱾�ε�����һ��һ�Σ�

                predCbn=o.attiCalculator.quat2cnb(predQ);

                [Fd,Gc,Fc]=o.getExponentMatFd(predCbn,step,acc_nose(i+1,:)-state(i+1,14:16),gyro_noise(i+1,:)-state(i+1,11:13));%accȡi�л���i+1�У�

%                 predErrorState(i+1,:)=predErrorState(i,:)*Fd';  %���״̬Ԥ��
                predErrorState(i+1,:)=zeros(1,15);
                
                Qd=o.getPredCovarianceMatQd(Gc,Fc,o.Qc,step);
                
                predP{i+1}=Fd*predP{i}*Fd'+Qd;                  %Ԥ��ƫ���������
                
%                 state(i+1,7:10)=o.QuatNormalize(state(i+1,7:10));%��Ԫ����һ���������´ε���֮ǰ��һ��һ�Σ�����ѧ������û�й�һ����
                
                if gps_noise(i+1,1)==1
                    %�����뿴���������˲��Ľ������������ʼ�ղ������if������䣬���м���
                    %�����GPS����ֵ���������������Լ�״̬ƫ�����
                    %����GPS����ֵ����̬�ǲ��ɹ۵ģ�������Ԫ�����£�������̬������ɢ������λ�ú��ٶ���һ��Ӱ�죩
                                        
                    [postErrorState,postP]=o.MeasurementUpdate((gps_noise(i+1,2:4)-state(i+1,1:3)),predP{i+1},predErrorState(i+1,:));
                    
                    predErrorState(i+1,:)=postErrorState;   %���µõ��ĺ���ƫ�����������Ԥ������еõ������鷽�����Թ��������ʹ��
                    predP{i+1}=postP;
                    
                    state(i+1,1:6)=state(i+1,1:6)+predErrorState(i+1,1:6);
                    
%                     %----------
%                     %��Ԫ����һ����ʽ1���ٹ�һ��ƫ����Ԫ�����ٽ�����Ԫ����˽���
%                     delta_q=0.5*predErrorState(i+1,7:9);    %�ɽǶ������µõ�����Ԫ��ʸ������������
%                     temp=delta_q*delta_q';
%                     if temp>1
%                         delta_q_hat=[1,delta_q]/sqrt(1+temp);
%                     else
%                         delta_q_hat=[sqrt(1-temp),delta_q];
%                     end
%                     state(i+1,7:10)=o.attiCalculator.QuatMulitMat(state(i+1,7:10),delta_q_hat');
%                     %----------
%                     
                    %----------
                    %��Ԫ����һ����ʽ2������Ԫ����ˣ��ٹ�һ��
                    state(i+1,7:10)=o.attiCalculator.QuatMulitMat(state(i+1,7:10),[1,0.5*predErrorState(i+1,7:9)]');
                    state(i+1,7:10)=o.QuatNormalize(state(i+1,7:10));
                    %----------
                    
                    state(i+1,11:16)=state(i+1,11:16)+predErrorState(i+1,10:15);    %����Ƿ���Ҫ����ƫ������Ժ�������������漰��̬�ľͲ�����
%                 else
%                     %û��GPS����ֵʱ�����ý���ƫ���������Ȼ�����ɢ
%                     state(i+1,1:6)=state(i+1,1:6)+predErrorState(i+1,1:6);
%                     state(i+1,11:16)=state(i+1,11:16)+predErrorState(i+1,10:15);
                end
            end
        end
        
        function state = statePrediction(o,state0,tspan,imudata,isODE45)
            %һ��״̬Ԥ��
            
            if isODE45
                %ode45�ٶȺ���
                %�����ÿһ������״̬Ԥ��
                [t,y] = ode45(@o.imuDynamics,tspan,state0,[],imudata);
                state = y(end,:);
            else
                step = tspan(2) - tspan(1);
                dy = o.imuDynamics([],state0,imudata);
                state = state0 + step*dy;
            end
        end
        
        function [Fd,Gc,Fc]=getExponentMatFd(o,predCbn,step,a_hat,omega_hat)
            %�������״̬���̣�ƫ�����ⷽ�̣�����ɢ���ſ˱Ⱦ���Fd���Լ���ɢ�������ſ˱Ⱦ���Gc���������Ի�����ɢ���������̣�
            %preCbn��    Ԥ��״̬���̣�Ԥ�����ⷽ�̣��õ�����ϵ��Ե���ϵ����ת����
            %step��      ����
            %a_hat��     a_hat=acc-ba_hat���ӱ����Լ��ٶȲ���ֵ��ȥԤ��Ư��ֵ������ba_hat�ݶ���Ϊ0
            %omega_hat�� omega_hat=gyro-bw_hat�������ǽ��ٶȲ���ֵ��ȥԤ��Ư��ֵ������bw_hat�ݶ���Ϊ0
            
            skew_a_hat=o.attiCalculator.a2skew_a(a_hat);
            skew_omega_hat=o.attiCalculator.a2skew_a(omega_hat);
            
            A=-predCbn'*skew_a_hat*(step^2/2*eye(3)-step^3/6*skew_omega_hat+step^4/24*skew_omega_hat^2);
            B=-predCbn'*skew_a_hat*(-step^3/6*eye(3)+step^4/24*skew_omega_hat-step^5/120*skew_omega_hat^2);
            C=-predCbn'*skew_a_hat*(step*eye(3)-step^2/2*skew_omega_hat+step^3/6*skew_omega_hat^2);
            D=-A;
            E=eye(3)-step*skew_omega_hat+step^2/2*skew_omega_hat^2;
            F=-step*eye(3)+step^2/2*skew_omega_hat-step^3/6*skew_omega_hat^2;
            
            Fd=[eye(3) step*eye(3) A B -predCbn'*step*step/2
                zeros(3) eye(3) C D -predCbn'*step
                zeros(3) zeros(3) E F zeros(3)
                zeros(3) zeros(3) zeros(3) eye(3) zeros(3)
                zeros(3) zeros(3) zeros(3) zeros(3) eye(3)];
            Gc=[zeros(3) zeros(3) zeros(3) zeros(3)
                -predCbn' zeros(3) zeros(3) zeros(3)
                zeros(3) zeros(3) -eye(3) zeros(3)
                zeros(3) zeros(3) zeros(3) eye(3)
                zeros(3) eye(3) zeros(3) zeros(3)];
            Fc=[zeros(3) eye(3) zeros(3) zeros(3) zeros(3)
                zeros(3) zeros(3) -predCbn'*skew_a_hat zeros(3) -predCbn'
                zeros(3) zeros(3) -skew_omega_hat -eye(3) zeros(3)
                zeros(3) zeros(3) zeros(3) zeros(3) zeros(3)
                zeros(3) zeros(3) zeros(3) zeros(3) zeros(3)];
        end
        
        function Qd=getPredCovarianceMatQd(o,Gc,Fc,Qc,step)
            %������ɢϵͳԤ������������Qd
            %Fc��    ƫ��Ԥ��״̬�����ſ˱Ⱦ���
            %Gc��    ƫ��Ԥ��״̬���̹����������ſ˱Ⱦ���
            %Qc��    ������������
            %step��  ����

            Q_hat=Gc*Qc*Gc';
            Qd=step*Q_hat+step^2*(0.5*Fc*Q_hat+Q_hat*0.5*Fc');
        end
        
        function [postErrorState,postP]=MeasurementUpdate(o,error_gps_noise,predP,predErrorState)
            %������º���
            %error_gps_noise��   GPS����ֵƫ�������ֵ�����ֵ֮��˴�ʹ�ü�ӿ������˲���
            %predP��             ����ƫ������
            %predErrorState��    ����ƫ�����ֵ
            
            H=[eye(3) zeros(3,12)];                 %�������
            K=predP*H'*(H*predP*H'+o.Rc)^-1;        %kalman����
            
            postErrorState=predErrorState+(error_gps_noise-predErrorState*H')*K';%����ƫ��״̬����
            
            postP=predP-K*H*predP;                  %����ƫ��������
        end
        
        function Q=QuatNormalize(o,q)
            %��Ԫ����һ��
            %q��������Ԫ��
            
            Q=q/norm(q);
        end
    end
    
end