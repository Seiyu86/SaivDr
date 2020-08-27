classdef TestCaseRefractIdx2Reflect < matlab.unittest.TestCase
    %TESTCASEREFRACTIDX2REFL ���̃N���X�̊T�v�������ɋL�q
    %   �ڍא����������ɋL�q
    
    properties
        dltFcn
        adtFcn
    end
    
    properties (TestParameter)
        mode = { 'Reflection','Linear','Signed-Quadratic','Identity'};
        dim1 = struct('small',8, 'large', 32);
        dim2 = struct('small',8, 'large', 32);
        dim3 = struct('small',8, 'large', 32);
        vrange = struct('small',[1.0 1.5], 'large',[0.5 2.0]);
    end
    
    methods (TestClassSetup)
        function addFunctions(testCase)
            kernelxy = kron([ 1 2 1 ].', [ 1 2 1 ]);
            kernelz  = permute([ 1 0 -1 ].',[ 2 3 1 ]);
            sobel3d = convn(kernelxy,kernelz)/32;
            absbl3d = abs(sobel3d);
            testCase.dltFcn = @(x) imfilter(x,sobel3d,'conv','circ');
            testCase.adtFcn = @(x) imfilter(x,absbl3d,'conv','circ');
        end
    end
    
    methods (Test)
        function testConstruction(testCase)
            
            phimExpctd = 'Reflection';
            outmExpctd = 'Function';
            
            % �C���X�^���X����
            target = RefractIdx2Reflect();
            
            phimActual = target.PhiMode;
            outmActual = target.OutputMode;
            
            testCase.verifyEqual(phimActual,phimExpctd);
            testCase.verifyEqual(outmActual,outmExpctd);
            
        end
        
        function testPhiMode(testCase,mode)
            
            % �C���X�^���X����
            target = RefractIdx2Reflect('PhiMode',mode);
            
            modeActual = target.PhiMode;
            
            testCase.verifyEqual(modeActual,mode);
            
        end
        
        function testStepReflection(testCase,dim1,dim2,dim3)
            
            
            % �ݒ�
            height = dim1;
            width  = dim2;
            depth  = dim3;
            phiMode   = 'Reflection';
            srcImg = rand(height,width,depth);
            
            %
            arrayDltU = testCase.dltFcn(srcImg);
            arrayAddU = testCase.adtFcn(srcImg);
            resExpctd = -(1./(arrayAddU.*arrayAddU)).*abs(arrayDltU).*arrayDltU;
            
            % �C���X�^���X����
            target = RefractIdx2Reflect('PhiMode',phiMode);
            
            %
            resActual = target.step(srcImg);
            
            % �]��
            testCase.verifySize(resActual,size(resExpctd));
            diff = max(abs(resExpctd(:) - resActual(:))./abs(resExpctd(:)));
            testCase.verifyEqual(resActual,resExpctd,'RelTol',1e-7,sprintf('%g',diff));
            
        end
        
        function testStepLinear(testCase,dim1,dim2,dim3,vrange)
            
            
            % �ݒ�
            height = dim1;
            width  = dim2;
            depth  = dim3;
            phiMode   = 'Linear';
            srcImg = rand(height,width,depth);
            
            %
            vmin   = vrange(1);
            vmax   = vrange(2);
            beta1   = 2*abs(vmax-vmin)/(vmax+vmin)^2;
            resExpctd = -beta1*testCase.dltFcn(srcImg);
            
            % �C���X�^���X����
            target = RefractIdx2Reflect(...
                'PhiMode',phiMode,...
                'VRange',vrange);
            
            %
            resActual = target.step(srcImg);
            
            % �]��
            testCase.verifySize(resActual,size(resExpctd));
            diff = max(abs(resExpctd(:) - resActual(:))./abs(resExpctd(:)));
            testCase.verifyEqual(resActual,resExpctd,'RelTol',1e-7,sprintf('%g',diff));
            
        end
        
        function testStepSignedQuadratic(testCase,dim1,dim2,dim3,vrange)
            
            % �ݒ�
            height = dim1;
            width  = dim2;
            depth  = dim3;
            phiMode   = 'Signed-Quadratic';
            srcImg = rand(height,width,depth);
            
            %
            vmin   = vrange(1);
            vmax   = vrange(2);
            beta2   = 4/(vmax+vmin)^2;
            arrayDltU = testCase.dltFcn(srcImg);
            resExpctd = -beta2*abs(arrayDltU).*arrayDltU;
            
            % �C���X�^���X����
            target = RefractIdx2Reflect(...
                'PhiMode',phiMode,...
                'VRange',vrange);
            
            %
            resActual = target.step(srcImg);
            
            % �]��
            testCase.verifySize(resActual,size(resExpctd));
            diff = max(abs(resExpctd(:) - resActual(:))./abs(resExpctd(:)));
            testCase.verifyEqual(resActual,resExpctd,'RelTol',1e-7,sprintf('%g',diff));
            
        end
        
        function testStepIdentity(testCase,dim1,dim2,dim3)
            
            % �ݒ�
            height = dim1;
            width  = dim2;
            depth  = dim3;
            phiMode   = 'Identity';
            srcImg = rand(height,width,depth);
            
            %
            resExpctd = srcImg;
            
            % �C���X�^���X����
            target = RefractIdx2Reflect('PhiMode',phiMode);
            
            %
            resActual = target.step(srcImg);
            
            % �]��
            testCase.verifySize(resActual,size(resExpctd));
            diff = max(abs(resExpctd(:) - resActual(:))./abs(resExpctd(:)));
            testCase.verifyEqual(resActual,resExpctd,'RelTol',1e-7,sprintf('%g',diff));
            
        end
        
        function testStepJacobian(testCase,mode,vrange)
            
            % �ݒ�
            height = 8;
            width  = 8;
            depth  = 16;
            vmin   = vrange(1);
            vmax   = vrange(2);
            srcImg = (vmax-vmin)*rand(height,width,depth)+vmin;
            delta = 1e-6; % ���l�����̍��ݕ�
            
            % ���l�I����
            nRows = numel(srcImg);
            jacobExpctd = zeros(nRows);
            phi = RefractIdx2Reflect('PhiMode',mode,'VRange',vrange);
            for iRow = 1:nRows
                du = zeros(size(srcImg));
                du(iRow) = delta;
                vecD = (phi.step(srcImg+du/2)-phi.step(srcImg-du/2))/delta;
                jacobExpctd(iRow,:) = vecD(:);
            end
            
            % �C���X�^���X����
            target = RefractIdx2Reflect(...
                'PhiMode',mode,...
                'VRange',vrange,...
                'OutputMode','Jacobian');
            
            % ��͓I����
            jacobActual = target.step(srcImg);
            
            % �]��
            testCase.verifySize(jacobActual,size(jacobExpctd));
            diff = max(abs(jacobExpctd(:) - jacobActual(:)));
            testCase.verifyEqual(jacobActual,jacobExpctd,'AbsTol',1e-7,sprintf('%g',diff));
            
        end
        
        function testStepGradient(testCase,mode,vrange)
            
            % �ݒ�
            height = 8;
            width  = 8;
            depth  = 16;
            vmin   = vrange(1);
            vmax   = vrange(2);
            delta = 1e-4; % ���l�����̍��ݕ�
            
            % ����
            vrange = [vmin vmax];
            u   = (vmax-vmin)*rand(height,width,depth)+vmin;
            phi = RefractIdx2Reflect('PhiMode','Reflection');                                    
            v   = phi.step(u)+0.1*randn(size(u));

              
            % ���l�I���z
            phiapx = RefractIdx2Reflect(...
                'PhiMode',mode,...
                'VRange',vrange,...
                'OutputMode','Function');                        
            [nRows,nCols,nLays] = size(u);
            gradExpctd = zeros(size(u));
            for iLay = 1:nLays
                for iCol = 1:nCols
                    for iRow = 1:nRows
                        du = zeros(size(u));
                        du(iRow,iCol,iLay) = delta;
                        % y = ��(u)-r 
                        y1 = phiapx.step(u+du/2)-v;
                        y2 = phiapx.step(u-du/2)-v;                        
                        % f = (1/2)||y||_2^2                        
                        f1 = (1/2)*norm(y1(:),2)^2;                        
                        f2 = (1/2)*norm(y2(:),2)^2;                                                
                        %
                        dltF = (f1-f2)/delta;
                        gradExpctd(iRow,iCol,iLay) = dltF;
                    end
                end
            end
            
            % �C���X�^���X����
            target = RefractIdx2Reflect(...
                'PhiMode',mode,...
                'VRange',vrange,...
                'OutputMode','Gradient');
            
            % ��͓I���z
            r = phiapx.step(u)-v;
            gradActual = target.step(u,r);
            
            % �]��
            testCase.verifySize(gradActual,size(gradExpctd));
            diff = max(abs(gradExpctd(:) - gradActual(:)));
            testCase.verifyEqual(gradActual,gradExpctd,'AbsTol',1e-7,sprintf('%g',diff));
            
        end
        
        function testStepCloneGradient(testCase,mode,vrange)
            
            % �ݒ�
            height = 8;
            width  = 8;
            depth  = 16;
            vmin   = vrange(1);
            vmax   = vrange(2);
            delta = 1e-4; % ���l�����̍��ݕ�
            
            % ���Ғl
            phiModeExpctd = mode;
            vrangeExpctd = vrange;
            outModeExpctd = 'Gradient';
            numInputsExpctd = 2;
            
            % ����
            vrange = [vmin vmax];
            u   = (vmax-vmin)*rand(height,width,depth)+vmin;
            phi = RefractIdx2Reflect('PhiMode','Reflection');                                    
            v   = phi.step(u)+0.1*randn(size(u));
              
            % ���l�I���z
            phiapx = RefractIdx2Reflect(...
                'PhiMode',mode,...
                'VRange',vrange,...
                'OutputMode','Function');                        
            [nRows,nCols,nLays] = size(u);
            gradExpctd = zeros(size(u));
            for iLay = 1:nLays
                for iCol = 1:nCols
                    for iRow = 1:nRows
                        du = zeros(size(u));
                        du(iRow,iCol,iLay) = delta;
                        % y = ��(u)-r 
                        y1 = phiapx.step(u+du/2)-v;
                        y2 = phiapx.step(u-du/2)-v;                        
                        % f = (1/2)||y||_2^2                        
                        f1 = (1/2)*norm(y1(:),2)^2;                        
                        f2 = (1/2)*norm(y2(:),2)^2;                                                
                        %
                        dltF = (f1-f2)/delta;
                        gradExpctd(iRow,iCol,iLay) = dltF;
                    end
                end
            end
            
            % �C���X�^���X����
            target = clone(phiapx);
            target.release();
            target.OutputMode = 'Gradient';
            
            phiModeActual = target.PhiMode;
            vrangeActual  = target.VRange;
            outModeActual = target.OutputMode;
            
            % ��͓I���z
            r = phiapx.step(u)-v;
            gradActual = target.step(u,r);
            
            % �]��
            testCase.verifyEqual(phiModeActual,phiModeExpctd);
            testCase.verifyEqual(vrangeActual,vrangeExpctd);
            testCase.verifyEqual(outModeActual,outModeExpctd);
            testCase.verifySize(gradActual,size(gradExpctd));
            diff = max(abs(gradExpctd(:) - gradActual(:)));
            testCase.verifyEqual(gradActual,gradExpctd,'AbsTol',1e-7,sprintf('%g',diff));
            
        end
        
    end
    
end
