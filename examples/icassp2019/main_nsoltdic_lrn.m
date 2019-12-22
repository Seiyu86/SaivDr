% MAIN_NSOLTDIC_LRN
% NSOLT�����w�K�X�N���v�g
%
% SaivDr �p�b�P�[�W�Ƀp�X��ʂ��Ă��������B
%
% ��
%
% >> setpath 
%
% ���茋��(VTK)���@
%
%   '../DATA(20170906)/VTK/';
%
% �ɗp�ӂ��āA�ȉ��̃R�}���h�Ń|�C���g�N���E�h�����Ă��������B
%
% >> main_vtk2pcd
%

%% �R���t�B�O���[�V����
isVisible = true;
diclrnconfig.srcFolder = RiverCpsConfig.SrcFolder;
diclrnconfig.dicFolder = RiverCpsConfig.DicFolder;

%% ���Ԑݒ�
diclrnconfig.ts = RiverCpsConfig.TsTraining; % start
diclrnconfig.te = RiverCpsConfig.TeTraining; % end
diclrnconfig.ti = RiverCpsConfig.TiTraining; % interval

%% �����p�����[�^
scale = 1024;
map = colormap();

%% �w�K�p�f�[�^�t�B�[���h
diclrnconfig.fieldList = RiverCpsConfig.FieldListTraining;
nFields = numel(diclrnconfig.fieldList);

%% �f�[�^�ǂݍ��݂Ɛ��`
iFrame = 0;
nFrames = (diclrnconfig.te-diclrnconfig.ts)/diclrnconfig.ti + 1;
frameSeq = cell(nFrames,1);
for t = diclrnconfig.ts:diclrnconfig.ti:diclrnconfig.te
    iFrame = iFrame + 1;
    filename = sprintf('%04d_trm',t);
    disp(filename)
    for iField = 1:nFields
        field = diclrnconfig.fieldList{iField};
        ptCloud = pcread([ diclrnconfig.srcFolder field '_' filename '.pcd' ]);
        undImg = permute(ptCloud.Location(:,:,3),RiverCpsConfig.getDimOrd());
        frameSeq{iFrame}(:,:,iField) = undImg;
    end
end

%% �P���f�[�^�\��
if isVisible
    hImg = cell(nFields,1);
    hFig1 = figure(1);
    for iFrame = 1:nFrames
        undImg = frameSeq{iFrame};
        if iFrame == 1
            figure(hFig1)
            for iField = 1:nFields
                subplot(nFields,1,iField)
                hImg{iField} = imshow(fliplr(scale*undImg(:,:,iField)),map);
            end
        else
            for iField = 1:nFields
                hImg{iField}.CData = fliplr(scale*undImg(:,:,iField));
            end
        end
        pause(0.1)
        drawnow
    end
end

%% NSOLT�P���f�[�^����
% �[����2�ŌŒ�
diclrnconfig.nSubPtcs  = RiverCpsConfig.NumPatchesTraining; % # of patches
diclrnconfig.virWidth  = RiverCpsConfig.VirWidthTraining;   % Virtual width of training images
diclrnconfig.virLength = RiverCpsConfig.VirLengthTraining;  % Virtual height of training images

% �P���f�[�^�̃����_�����o
diclrnconfig.width  = size(frameSeq{1},RiverCpsConfig.DIRECTION_WIDTH);
diclrnconfig.length = size(frameSeq{1},RiverCpsConfig.DIRECTION_LENGTH);
diclrnconfig.depth  = 2;
%
trnImgs = cell(diclrnconfig.nSubPtcs);
rng(0,'twister');
for iSubPtc = 1:diclrnconfig.nSubPtcs
    pl = randi([0 (diclrnconfig.length-diclrnconfig.virLength)]); % ��������
    pw = randi([0 (diclrnconfig.width-diclrnconfig.virWidth)]);   % ���f����
    pf = randi([1 nFrames]);            % �t���[��
    %
    undImg = frameSeq{pf};
    trnImgs{iSubPtc} = ...
        im2double(undImg(pw+(1:diclrnconfig.virWidth),pl+(1:diclrnconfig.virLength),:));
end

%% 
if RiverCpsConfig.IsVisible
    hfig1 = findobj(get(groot,'Children'),'Name','Sparse Approximation');
    if isempty(hfig1)
        hfig1 = figure;
        set(hfig1,'Name','Sparse Approximation')
    end
    %
    hfig2 = findobj(get(groot,'Children'),'Name','Atomic Images');
    if isempty(hfig2)
        hfig2 = figure;
        hfig2.Name= 'Atomic Images';
    end
end

%% NSOLT�w�K(ISTA+SGD)
diclrnconfig.nIters = RiverCpsConfig.NumberOfOuterIterations; % �J��Ԃ���
plotFcn             = @optimplotfval;

% ISTA�X�e�b�v�V�X�e���̃C���X�^���X��
import saivdr.restoration.ista.IstaSystem
algorithm = IstaSystem(...
    'DataType','Volumetric Data',...
    'Lambda',RiverCpsConfig.LambdaNsoltTraining);

% �X�e�b�v���j�^�[�V�X�e���̃C���X�^���X��
import saivdr.utility.StepMonitoringSystem
stepMonitor = StepMonitoringSystem(...
    'DataType','Volumetric Data',...    
    'EvaluationType','double',...
    'ImageFigureHandle',hfig1,...
    'IsRMSE',true,...
    'IsMSE',true,...    
    'IsVisible',false,...RiverCpsConfig.IsVisible,...
    'IsVerbose',RiverCpsConfig.IsVerbose);

% �X�p�[�X�ߎ��V�X�e���̃C���X�^���X��
import saivdr.sparserep.IterativeSparseApproximater
sprsAprx = IterativeSparseApproximater(...
    'Algorithm',algorithm,...
    'StepMonitor',stepMonitor,...
    'MaxIter',RiverCpsConfig.MaxIterOfIterativeSparseApproximater,...
    'TolErr',RiverCpsConfig.TolErr);

% �����X�V�V�X�e���̃C���X�^���X��
import saivdr.dictionary.nsoltx.design.NsoltDictionaryUpdateSgd
dicUpd = NsoltDictionaryUpdateSgd(...
    'IsVerbose', RiverCpsConfig.IsVerbose,...
    'GradObj',RiverCpsConfig.GradObj,...
    'Step',RiverCpsConfig.SgdStep,....
    'AdaGradEta',RiverCpsConfig.AdaGradEta,...
    'AdaGradEps',RiverCpsConfig.AdaGradEps);

% �����w�K�V�X�e���̃C���X�^���X��
import saivdr.dictionary.nsoltx.design.NsoltDictionaryLearningPnP
designer = NsoltDictionaryLearningPnP(...
    'DataType', 'Volumetric Data',...
    'DecimationFactor',RiverCpsConfig.DecimationFactor,...
    'NumberOfLevels',RiverCpsConfig.NumberOfLevels,...    
    'NumberOfChannels', RiverCpsConfig.NumberOfChannels,...
    'PolyPhaseOrder',RiverCpsConfig.PolyPhaseOrder,...
    'NumberOfVanishingMoments',RiverCpsConfig.NumberOfVanishingMoments,...
    'SparseApproximater',sprsAprx,...
    'DictionaryUpdater',dicUpd,...
    'IsRandomInit', RiverCpsConfig.IsRandomInit,...
    'StdOfAngRandomInit', RiverCpsConfig.StdOfAngRandomInit);
%
diclrnconfig.options = optimset(...
    'Display','iter',...
    'PlotFcn',plotFcn,...
    'MaxIter',RiverCpsConfig.MaxIterOfDictionaryUpdater);

%% �����w�K
for iter = 1:diclrnconfig.nIters
    [ nsolt, mse ] = designer.step(trnImgs,diclrnconfig.options);
    fprintf('MSE (%d) = %g\n',iter,mse)
    if isVisible
        % Show the atomic images by using a method atmimshow()
        figure(hfig2)
        nsolt.atmimshow()
        drawnow
    end
end

%%
imgName = 'rivercps';
if ~exist(diclrnconfig.dicFolder,'dir')
    mkdir(diclrnconfig.dicFolder);
end
fileName = sprintf(...
    '%snsolt_d%dx%dx%d_c%d+%d_o%d+%d+%d_v%d_lv%d_lmd%s_%s_sgd.mat',...
    diclrnconfig.dicFolder,...
    RiverCpsConfig.DecimationFactor(1),...
    RiverCpsConfig.DecimationFactor(2),...
    RiverCpsConfig.DecimationFactor(3),...
    RiverCpsConfig.NumberOfChannels(1),...
    RiverCpsConfig.NumberOfChannels(2),...
    RiverCpsConfig.PolyPhaseOrder(1),...
    RiverCpsConfig.PolyPhaseOrder(2),...
    RiverCpsConfig.PolyPhaseOrder(3),...
    RiverCpsConfig.NumberOfVanishingMoments,...
    RiverCpsConfig.NumberOfLevels,...
    strrep(num2str(RiverCpsConfig.LambdaNsoltTraining,'%g'),'.','_'),...
    [imgName num2str(diclrnconfig.virLength) 'x' num2str(diclrnconfig.virWidth)]);
save(fileName,'nsolt','designer','mse','diclrnconfig');