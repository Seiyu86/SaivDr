% MAIN_CSCDMD_RST
% �􍞂݃X�p�[�X���������I���[�h����(CSC-DMD)�����X�N���v�g
%
% SaivDr �p�b�P�[�W�Ƀp�X��ʂ��Ă��������B
%
% ��
%
% >> setpath 
%
% NSOLT�̐݌v��CSCDMD�̊w�K���Ɋ��������Ă��������B
%
% >> main_nsoltdic_lrn
% >> main_cscdmd_lrn
%

%% �R���t�B�O���[�V����
isVisibule = true;
dmdrstconfig.srcFolder = RiverCpsConfig.SrcFolder;
dmdrstconfig.dstFolder = RiverCpsConfig.DstFolder;
dmdrstconfig.dicFolder = RiverCpsConfig.DicFolder;
dmdrstconfig.virLength = RiverCpsConfig.VirLengthTraining;
dmdrstconfig.virWidth = RiverCpsConfig.VirWidthTraining;

%% ���Ԑݒ�
dmdrstconfig.ts = RiverCpsConfig.TsRestoration; % start
dmdrstconfig.te = RiverCpsConfig.TeRestoration; % end
dmdrstconfig.ti = RiverCpsConfig.TiRestoration; % interval

%% �݌v�f�[�^�̓ǂݍ���
imgName = 'rivercps';
fileName = sprintf(...
    '%snsolt_d%dx%dx%d_c%d+%d_o%d+%d+%d_v%d_vl%d_vn%d_%s_sgd.mat',...
    dmdrstconfig.dicFolder,...
    RiverCpsConfig.DecimationFactor(1),...
    RiverCpsConfig.DecimationFactor(2),...
    RiverCpsConfig.DecimationFactor(3),...
    RiverCpsConfig.NumberOfChannels(1),...
    RiverCpsConfig.NumberOfChannels(2),...
    RiverCpsConfig.NumberOfPolyphaseOrder(1),...
    RiverCpsConfig.NumberOfPolyphaseOrder(2),...
    RiverCpsConfig.NumberOfPolyphaseOrder(3),...
    RiverCpsConfig.OrderOfVanishingMoment,...
    RiverCpsConfig.NumberOfLevels,...
    RiverCpsConfig.NumberOfSparseCoefsTraining,...
    [imgName num2str(dmdrstconfig.virLength) 'x' num2str(dmdrstconfig.virWidth)]);
S = load(fileName,'nsolt','Phi','b','lambda');
nsolt = S.nsolt;
Phi = S.Phi;
b = S.b;
lambda = S.lambda;

%% ���́E�����V�X�e���̃C���X�^���X��
import saivdr.dictionary.nsoltx.NsoltFactory
analyzer    = NsoltFactory.createAnalysis3dSystem(nsolt);
synthesizer = NsoltFactory.createSynthesis3dSystem(nsolt);
analyzer.BoundaryOperation = 'Termination';
synthesizer.BoundaryOperation = 'Termination';

%% �����p�f�[�^�t�B�[���h
dmdrstconfig.fieldList = RiverCpsConfig.FieldListRestoration;
nFields = numel(dmdlrnconfig.fieldList);

%% �v���f�[�^�̓ǂݍ��݂Ɛ��`
iFrame = 0;
nFrames = (dmdrstconfig.te-dmdrstconfig.ts)/dmdrstconfig.ti + 1;
surfObsvSeq = cell(nFrames,1);
bedExpctSeq = cell(nFrames,1);
nDec = RiverCpsConfig.DecimationFactor(1:2);
for t = dmdrstconfig.ts:dmdrstconfig.ti:dmdrstconfig.te
    iFrame = iFrame + 1;
    filename = sprintf('%04d_trm',t);
    disp(filename)
    % Surface
    field = dmdrstconfig.fieldList{1};
    ptCloud = pcread([ dmdrstconfig.srcFolder field '_' filename '.pcd' ]);
    undImg = permute(ptCloud.Location(:,:,3),RiverCpsConfig.getDimOrd());
    padSize = ceil(size(undImg)./nDec(:).').*nDec(:).'-size(undImg);
    surfObsvSeq{iFrame} = padarray(undImg,padSize,'post');    
    % Bed
    field = dmdrstconfig.fieldList{2};
    ptCloud = pcread([ dmdrstconfig.srcFolder field '_' filename '.pcd' ]);
    undImg = permute(ptCloud.Location(:,:,3),RiverCpsConfig.getDimOrd());
    padSize = ceil(size(undImg)./nDec(:).').*nDec(:).'-size(undImg);
    bedExpctSeq{iFrame} = padarray(undImg,padSize,'post');
end

%% �X�p�[�X����(IHT)
import saivdr.sparserep.IterativeHardThresholding
import saivdr.utility.StepMonitoringSystem
stepMonitor = StepMonitoringSystem(...
    'DataType','Volumetric Data',...
    'IsVerbose',true,...
    'IsMSE',true);
sparseCoder = IterativeHardThresholding(...
    'Synthesizer',synthesizer,...
    'AdjOfSynthesizer',analyzer,...
    'StepMonitor',stepMonitor);

%% �X�p�[�X�ߎ�(IHT)�̎��s
dmdrstconfig.nSprsCoefs = RiverCpsConfig.NumberOfSparseCoefsEdmd;
for iFrame = 1:nFrames
    srcVol = frameSeq{iFrame};
    stepMonitor.SourceImage = srcVol;
    [~, sparseCoefs, setOfScales] = ...
        sparseCoder.step(srcVol,...
        dmdrstconfig.nSprsCoefs);
    featSeq(:,iFrame) = sparseCoefs(:);
    stepMonitor.release()
end