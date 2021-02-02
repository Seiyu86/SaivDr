% MAIN_CSCDMD_LRM
% �􍞂݃X�p�[�X���������I���[�h����(CSC-DMD)�w�K�X�N���v�g
%
% SaivDr �p�b�P�[�W�Ƀp�X��ʂ��Ă��������B
%
% ��
%
% >> setpath 
%
% NSOLT�̐݌v���Ɋ��������Ă��������B
%
% >> main_nsoltdic_lrn
%

%% �R���t�B�O���[�V����
isVisible = true;
dmdlrnconfig.srcFolder = RiverCpsConfig.SrcFolder;
dmdlrnconfig.dstFolder = RiverCpsConfig.DstFolder;
dmdlrnconfig.dicFolder = RiverCpsConfig.DicFolder;
dmdlrnconfig.virWidth  = RiverCpsConfig.VirWidthTraining;   % Virtual width of training images
dmdlrnconfig.virLength = RiverCpsConfig.VirLengthTraining;  % Virtual height of training images

%% ���Ԑݒ�
dmdlrnconfig.ts = RiverCpsConfig.TsTraining; % start
dmdlrnconfig.te = RiverCpsConfig.TeTraining; % end
dmdlrnconfig.ti = RiverCpsConfig.TiTraining; % interval

%% �����p�����[�^
map = colormap();
idxFig = 0;

%% �݌v�f�[�^�̓ǂݍ���
imgName = 'rivercps';
fileName = sprintf(...
    '%snsolt_d%dx%dx%d_c%d+%d_o%d+%d+%d_v%d_lv%d_lmd%s_%s_sgd.mat',...
    dmdlrnconfig.dicFolder,...
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
    [imgName num2str(dmdlrnconfig.virLength) 'x' num2str(dmdlrnconfig.virWidth)]);
    S = load(fileName,'nsolt');
    nsolt = S.nsolt;

if isVisible
    idxFig = idxFig + 1;
    hFigNsolt = figure(idxFig);
    nsolt.atmimshow()
    hFigNsolt.Position = [95 115 1011 175];
    ax = hFigNsolt.Children;
    for idx=1:length(ax)
        ax(idx).View = ax(idx).View.*[ -1 1];
        ax(idx).XDir = 'reverse';
    end
    drawnow
    %print(sprintf('%satmimg',dmdlrnconfig.dstFolder),'-dpng')    
end

%% ���́E�����V�X�e���̃C���X�^���X��
import saivdr.dictionary.nsoltx.NsoltFactory
analyzer    = NsoltFactory.createAnalysis3dSystem(nsolt);
synthesizer = NsoltFactory.createSynthesis3dSystem(nsolt);
analyzer.BoundaryOperation = 'Termination';
synthesizer.BoundaryOperation = 'Termination';

%% �w�K�p�f�[�^�t�B�[���h
dmdlrnconfig.fieldList = RiverCpsConfig.FieldListTraining;
nFields = numel(dmdlrnconfig.fieldList);

%% �v���f�[�^�̓ǂݍ��݂Ɛ��`
iFrame = 0;
nFrames = (dmdlrnconfig.te-dmdlrnconfig.ts)/dmdlrnconfig.ti + 1;
frameSeq = cell(nFrames,1);
nDec = RiverCpsConfig.DecimationFactor(1:2);
for t = dmdlrnconfig.ts:dmdlrnconfig.ti:dmdlrnconfig.te
    iFrame = iFrame + 1;
    filename = sprintf('%04d_trm',t);
    disp(filename)
    for iField = 1:nFields
        field = dmdlrnconfig.fieldList{iField};
        ptCloud = pcread([ dmdlrnconfig.srcFolder field '_' filename '.pcd' ]);
        undImg = permute(ptCloud.Location(:,:,3),RiverCpsConfig.getDimOrd());
        padSize = ceil(size(undImg)./nDec(:).').*nDec(:).'-size(undImg);
        frameSeq{iFrame}(:,:,iField) = padarray(undImg,padSize,'post');
    end
end

%% �P���f�[�^�\��
if isVisible
    hImg = cell(nFields,1);
    idxFig = idxFig+1;
    hFigSmpl = figure(idxFig);
    title('Traning Data')
    s = 1024;
    for iFrame = 1:nFrames
        undImg = frameSeq{iFrame};
        if iFrame == 1
            figure(hFigSmpl)
            for iField = 1:nFields
                subplot(nFields,1,iField)
                hImg{iField} = imshow(fliplr(s*undImg(:,:,iField)),map);
            end
        else
            for iField = 1:nFields
                hImg{iField}.CData = fliplr(s*undImg(:,:,iField));
            end
        end
        pause(0.1)
        drawnow
    end
end

%% ��Ԏ��n��̐���
dim = size(frameSeq{1});
len = prod(dim);
stateSeq = zeros(len,nFrames);
for iFrame = 1:nFrames
    undImg = frameSeq{iFrame};
    xs = undImg(:,:,1);
    xb = undImg(:,:,2);
    stateSeq(:,iFrame) = [ xs(:); xb(:) ];
end
                
%% �m�[�}��DMD�̎��s
X0 = stateSeq(:,1:end-1);
X1 = stateSeq(:,2:end);
dt = dmdlrnconfig.ti*60; % [s]
r = rank(X0);
disp(['r = ' num2str(r)])
support.fcn_setup_dmd
[PhiX,omegaX,lambdaX,bX,Xdmd] = DMD(X0,X1,r,dt);

if isVisible
    idxFig=idxFig+1;
    hFigNormMode = figure(idxFig);
    distance = dim(1);
    width = dim(2);
    modeArray = reshape(PhiX,distance,width,nFields,size(PhiX,2));
    s = 200;
    idx = 1;
    array = modeArray(:,:,:,idx);
    [watermode,bedmode] = support.fcn_mode2rgb(array,s);
    %
    him = imshow([
        watermode;
        ones(1,size(array,2),3);
        bedmode]);
    htl = title(['Mode ' num2str(idx,'%02d') ' (DMD)']);
    drawnow
    %imwrite(him.CData,sprintf('%smodeX%02d.png',dstfolder,1))
    
    idxFig=idxFig+1;
    hFigNormOmega = figure(idxFig);
    plot(real(omegaX),imag(omegaX),'o')
    for idx = 1:r
        text(real(omegaX(idx)),imag(omegaX(idx)),num2str(idx))
    end
    xlabel('\Re(\omega)')
    ylabel('\Im(\omega)')
    axis([-6 6 -6 6]*1e-3)
    axis square
    grid on
    title('\Omega (DMD)')
    drawnow
    %print(sprintf('%somegaY',dstfolder),'-dpng')
end
scalesX = dim;

%% �p�����[�^�̒��o
save(fileName,'scalesX','PhiX','omegaX','lambdaX','bX','Xdmd','dmdlrnconfig','-append');

%% �X�p�[�X�ߎ��̏���
dmdlrnconfig.lambda = RiverCpsConfig.LambdaCscDmdTraining;
% ISTA�X�e�b�v�V�X�e���̃C���X�^���X��
import saivdr.restoration.ista.IstaSystem
algorithm = IstaSystem(...
    'DataType','Volumetric Data',...
    'Lambda', dmdlrnconfig.lambda); 

% �X�e�b�v���j�^�[�V�X�e���̃C���X�^���X��
import saivdr.utility.StepMonitoringSystem
stepMonitor = StepMonitoringSystem(...
    'DataType','Volumetric Data',...    
    'EvaluationType','double',...
    ...'ImageFigureHandle',hFig3,...
    'IsRMSE',true,...
    'IsMSE',true,...    
    'IsVisible',false,...RiverCpsConfig.IsVisible,...
    'IsVerbose',RiverCpsConfig.IsVerbose);

% �X�p�[�X�ߎ��V�X�e���̃C���X�^���X��
dmdlrnconfig.maxitersprsaprx = RiverCpsConfig.MaxIterOfIterativeSparseApproximater;
dmdlrnconfig.tolerr = RiverCpsConfig.TolErr;
import saivdr.sparserep.IterativeSparseApproximater
sprsAprx = IterativeSparseApproximater(...
    'Algorithm',algorithm,...
    'Dictionary', { synthesizer, analyzer},...
    'StepMonitor',stepMonitor,...
    'MaxIter', dmdlrnconfig.maxitersprsaprx,...
    'TolErr',dmdlrnconfig.tolerr);

%% �X�p�[�X�ߎ��̎��s
for iFrame = 1:nFrames
    undImg = frameSeq{iFrame};
    sprsAprx.StepMonitor.reset();
    sprsAprx.StepMonitor.SourceImage = undImg;
    [aprx,coefvec,scalesY] = sprsAprx.step(undImg);
    featSeq(:,iFrame) = coefvec(:); 
    aprxSeq{iFrame} = aprx;
end

%% �g�����I���[�h����(EDMD)�̎��s
Y0 = featSeq(:,1:end-1);
Y1 = featSeq(:,2:end);
dt = dmdlrnconfig.ti*60; % [s]
r = rank(Y0);
disp(['r = ' num2str(r)])
support.fcn_setup_dmd
[PhiY,omegaY,lambdaY,bY,Ydmd] = DMD(Y0,Y1,r,dt);

if isVisible
    idxFig=idxFig+1;    
    hFigCscMode = figure(idxFig);
    s = 200;
    idxSet = [1, 2,9];
    for idx = idxSet
        arrayRe = synthesizer.step(real(PhiY(:,idx)),scalesY);
        arrayIm = synthesizer.step(imag(PhiY(:,idx)),scalesY);
        [watermode,bedmode] = support.fcn_mode2rgb(arrayRe+1i*arrayIm,s);
        %
        him = imshow([
            watermode;
            ones(1,size(array,2),3);
            bedmode]);
        htl = title(['Mode ' num2str(idx,'%02d') ' (CSC-DMD)']);
        drawnow
        imwrite(him.CData,sprintf('%smodeY%02d.png',dmdlrnconfig.dstFolder,idx))
    end

    idxFig=idxFig+1;        
    hFigCscOmega = figure(idxFig);
    plot(real(omegaY),imag(omegaY),'o');
    hFigCscOmega.Children.FontSize = 12;
    for idx = 1:r
        text(real(omegaY(idx)),imag(omegaY(idx)),num2str(idx),...
            'FontSize',12)
    end
    xlabel('\Re(\omega)')
    ylabel('\Im(\omega)')
    axis([-6 6 -6 6]*1e-3)
    axis square
    grid on
    title('\Omega (CSC-DMD)')
    drawnow
    print(sprintf('%somegaY',dmdlrnconfig.dstFolder),'-dpng')
end

%% �p�����[�^�̒��o
save(fileName,'scalesY','PhiY','omegaY','lambdaY','bY','Ydmd','dmdlrnconfig','-append');

%% �ߎ��f�[�^�̕\��
if isVisible
    hImg = cell(nFields,1);
    idxFig = idxFig+1;
    hFigAprx = figure(idxFig);
    title('Approximation (CSC-DMD)')
    s = 1024;
    for iFrame = 1:nFrames
        undImg = aprxSeq{iFrame};
        if iFrame == 1
            figure(hFigAprx)
            for iField = 1:nFields
                subplot(nFields,1,iField)
                hImg{iField} = imshow(fliplr(s*undImg(:,:,iField)),map);
            end
        else
            for iField = 1:nFields
                hImg{iField}.CData = fliplr(s*undImg(:,:,iField));
            end
        end
        pause(0.1)
        drawnow
    end
end
