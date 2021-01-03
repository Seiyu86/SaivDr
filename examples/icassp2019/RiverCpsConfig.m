classdef RiverCpsConfig 
    %Constants �萔
    %   �萔�̒�`
    
    properties (Constant)
        
        PTCLOUD_LENGTH = 1;
        PTCLOUD_WIDTH  = 2;
        
        DIRECTION_WIDTH  = 1;
        DIRECTION_LENGTH = 2;
        DIRECTION_DEPTH  = 3;
        
        % ���ʃp�����[�^
        VtkFolder = './DATA(20170906)/VTK/';
        SrcFolder = './data/';
        DstFolder = './data/';
        DicFolder = './dictionary/';
        
        FieldList = {
            'water_level' ...
            'bed_level' ...
            'depth_of_water' ...
            'deviation_of_bed_level'
        };
    
        DecimationFactor = [ 4 2 2 ];
        NumberOfChannels = [ 10 10 ];
        PolyPhaseOrder = [ 2 2 0 ];
        NumberOfLevels = 1;
        NumberOfVanishingMoments = 1;
        
        % CSC-DMD�����p�p�����[�^
        TsEstimation = 260;
        TeEstimation = 440;
        TiEstimation =  10;

        EpsilonSetEstimation = [ 2e-2 4e-2 8e-2 ]
        FieldListEstimation = { 'water_level', 'bed_level' };  
        LambdaNormDmdEstimation = 8e-3;        
        LambdaCscDmdEstimation = 8e-3;                
        MaxIterOfIterativeSparseRestorater = 128;
        GammaNormDmdEstimation = { 1e-3, 950 };
        GammaCscDmdEstimation = { 1e-3, 950 };        
        
        % CSC-DMD�݌v�p�p�����[�^
        %NumberOfSparseCoefsEdmd = 700; % �`41x851x2x0.01
        LambdaCscDmdTraining = 8e-3; % 
        
        % NSOLT�݌v�p�p�����[�^
        NumberOfOuterIterations = 16;
        MaxIterOfIterativeSparseApproximater = 128;
        MaxIterOfDictionaryUpdater = 128;
        
        FieldListTraining = { 'water_level', 'bed_level' };
        IsVerbose    = true;
        IsVisible    = true;
        IsFixedCoefs = true;
        IsRandomInit = true;
        StdOfAngRandomInit = 1e-2; % Available only for a single-level Type-I NSOLT
        GradObj      = 'on';
        SgdStep      = 'AdaGrad';
        AdaGradEta   = 1e-3; % Default 1e-2
        AdaGradEps   = 1e-9; % Deafult 1e-8
        
        TsTraining = 100; % �P���f�[�^�J�n����
        TeTraining = 250; % �P���f�[�^�I������
        TiTraining = 10;  % �P���f�[�^���ԊԊu
        
        NumPatchesTraining = 128; % �P���p�p�b�`��
        VirWidthTraining   =  32; % �p�b�`���i���f�����j
        VirLengthTraining  = 128; % �p�b�`���i���������j
        %nMeasure = 32*128;       % �ϑ��f�[�^��
        %nCoefs = 32*128* (20/16); % �ϊ��W���̐� 
        LambdaNsoltTraining = 8e-3; %
        TolErr = 1e-15;
        
    end
    
    methods (Static)
        
        function d = getDimOrd()
            d(RiverCpsConfig.DIRECTION_WIDTH) = ...
                RiverCpsConfig.PTCLOUD_WIDTH;
            d(RiverCpsConfig.DIRECTION_LENGTH) = ...
                RiverCpsConfig.PTCLOUD_LENGTH;            
        end
            
    end
    
end

