classdef TestCaseSobel3d < matlab.unittest.TestCase
    %TESTCASEPLGSOFTTHRESHOLDING ���̃N���X�̊T�v�������ɋL�q
    %   �ڍא����������ɋL�q
    
    properties (TestParameter)
        dim1 = struct('small',8,'medium',16,'large',32);
        dim2 = struct('small',8,'medium',16,'large',32);
        dim3 = struct('small',8,'medium',16,'large',32);
    end
    
    methods (Test)
        
        function testConstruction(testCase)
            
            % �ݒ�
            kernelxy = kron([ 1 2 1 ].', [ 1 2 1 ]);
            kernelz  = permute([ 1 0 -1 ].',[ 2 3 1 ]);
            kernelExpctd = convn(kernelxy,kernelz)/32;
            
            % �C���X�^���X��
            target = Sobel3d();
            
            kernelActual = target.Kernel;
            
            % Evaluation
            testCase.verifySize(kernelActual,size(kernelExpctd));
            diff = max(abs(kernelExpctd(:) - kernelActual(:))./abs(kernelExpctd(:)));
            testCase.verifyEqual(kernelActual,kernelExpctd,'RelTol',1e-7,sprintf('%g',diff));
        end
        
        function testStepNormal(testCase,dim1,dim2,dim3)
            
            % �ݒ�
            height = dim1;
            width  = dim2;
            depth  = dim3;
            
            kernelxy = kron([ 1 2 1 ].', [ 1 2 1 ]);
            kernelz  = permute([ 1 0 -1 ].',[ 2 3 1 ]);
            sobel3d = convn(kernelxy,kernelz)/32;
            
            src = rand(height,width,depth);
            resExpctd = imfilter(src,sobel3d,'conv','circ');
            kmdExpctd = 'Normal';
            
            % �C���X�^���X��
            target = Sobel3d();
            
            resActual = target.step(src);
            kmdActual = target.KernelMode;
            
            % Evaluation
            testCase.verifyEqual(kmdActual,kmdExpctd);
            testCase.verifySize(resActual,size(resExpctd));
            diff = max(abs(resExpctd(:) - resActual(:))./abs(resExpctd(:)));
            testCase.verifyEqual(resActual,resExpctd,'RelTol',1e-7,sprintf('%g',diff));
            
        end
        
        function testStepAbsolute(testCase,dim1,dim2,dim3)
            
            % �ݒ�
            height = dim1;
            width  = dim2;
            depth  = dim3;
            
            kernelxy = kron([ 1 2 1 ].', [ 1 2 1 ]);
            kernelz  = permute([ 1 0 -1 ].',[ 2 3 1 ]);
            sobel3d = convn(kernelxy,kernelz)/32;
            
            src = rand(height,width,depth);
            resExpctd = imfilter(src,abs(sobel3d),'conv','circ');
            kmdExpctd = 'Absolute';
            
            % �C���X�^���X��
            target = Sobel3d('KernelMode',kmdExpctd);
            
            resActual = target.step(src);
            kmdActual = target.KernelMode;
            
            % Evaluation
            testCase.verifyEqual(kmdActual,kmdExpctd);
            testCase.verifySize(resActual,size(resExpctd));
            diff = max(abs(resExpctd(:) - resActual(:))./abs(resExpctd(:)));
            testCase.verifyEqual(resActual,resExpctd,'RelTol',1e-7,sprintf('%g',diff));
            
        end
        
    end
end
