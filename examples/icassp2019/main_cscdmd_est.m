% MAIN_CSCDMD_EST
% �􍞂݃X�p�[�X���������I���[�h����(CSC-DMD)��ʐ���X�N���v�g
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
% CSC-DMD�̊w�K���Ɋ��������Ă��������B
%
% >> main_cscdmd_lrn
%

%% �R���t�B�O���[�V����
isVisible = true;
dmdestconfig.srcFolder = RiverCpsConfig.SrcFolder;
dmdestconfig.dstFolder = RiverCpsConfig.DstFolder;
dmdestconfig.dicFolder = RiverCpsConfig.DicFolder;
dmdestconfig.virWidth  = RiverCpsConfig.VirWidthTraining;   % Virtual width of training images
dmdestconfig.virLength = RiverCpsConfig.VirLengthTraining;  % Virtual height of training images

%% ���Ԑݒ�
dmdestconfig.ts = RiverCpsConfig.TsEstimation; % start
dmdestconfig.te = RiverCpsConfig.TeEstimation; % end
dmdestconfig.ti = RiverCpsConfig.TiEstimation; % interval

%% �����p�����[�^
map = colormap();
idxFig = 0;

%% rmse �̒�`
rmse = @(x,y) norm(x(:)-y(:),2)/sqrt(numel(x));

%% �݌v�f�[�^�̓ǂݍ���
imgName = 'rivercps';
fileName = sprintf(...
    '%snsolt_d%dx%dx%d_c%d+%d_o%d+%d+%d_v%d_lv%d_lmd%s_%s_sgd.mat',...
    dmdestconfig.dicFolder,...
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
    [imgName num2str(dmdestconfig.virLength) 'x' num2str(dmdestconfig.virWidth)]);
    S = load(fileName);

%% �e�X�g�p�f�[�^�t�B�[���h
dmdestconfig.fieldList = RiverCpsConfig.FieldListEstimation;
nFields = numel(dmdestconfig.fieldList);

%% �v���f�[�^�̓ǂݍ��݂Ɛ��`
iFrame = 0;
nFrames = (dmdestconfig.te-dmdestconfig.ts)/dmdestconfig.ti + 1;
frameSeq = cell(nFrames,1);
nDec = RiverCpsConfig.DecimationFactor(1:2);
for t = dmdestconfig.ts:dmdestconfig.ti:dmdestconfig.te
    iFrame = iFrame + 1;
    filename = sprintf('%04d_trm',t);
    disp(filename)
    for iField = 1:nFields
        field = dmdestconfig.fieldList{iField};
        ptCloud = pcread([ dmdestconfig.srcFolder field '_' filename '.pcd' ]);
        undImg = permute(ptCloud.Location(:,:,3),RiverCpsConfig.getDimOrd());
        padSize = ceil(size(undImg)./nDec(:).').*nDec(:).'-size(undImg);
        frameSeq{iFrame}(:,:,iField) = padarray(undImg,padSize,'post');
    end
end

%% �e�X�g�f�[�^�\��
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

%% ����̐ݒ�
dmdestconfig.epsSet = RiverCpsConfig.EpsilonSetEstimation; 
timeSet = dmdestconfig.ts:dmdestconfig.ti:dmdestconfig.te;

%% ���[�h�C�ŗL�l�̓ǂݍ���(DMD)
PhiX = S.PhiX;
lambdaX = S.lambdaX;
omegaX = S.omegaX;
bX = S.bX;
scalesX = S.scalesX;

%% �P���ϊ��i���́E�����V�X�e���j�̃C���X�^���X��
import saivdr.dictionary.utility.*
analyzeridnt    = IdentityAnalysisSystem();
synthesizeridnt = IdentitySynthesisSystem();

%% �X�p�[�X�M�������̏���(DMD)
dmdestconfig.normgamma = RiverCpsConfig.GammaNormDmdEstimation;
dmdestconfig.normlambda = RiverCpsConfig.LambdaNormDmdEstimation;
dmdestconfig.maxIter = RiverCpsConfig.MaxIterOfIterativeSparseRestorater;
dmdestconfig.tolerr = RiverCpsConfig.TolErr;

% �ϑ��ߒ��̏���
msrProc = support.SurfaceExtractionSystem();

% �����ˉe�̏���
import saivdr.restoration.metricproj.*
mtrProj = ProxNormBallConstraint();

% �n�[�h����t��ISTA�X�e�b�v�V�X�e���̃C���X�^���X��
import saivdr.restoration.pds.IstHcSystem
algorithm = IstHcSystem(...
    ...'Observation',    vObs,...
    'DataType', 'Volumetric Data',...
    'Gamma',dmdestconfig.normgamma,...
    'Lambda',dmdestconfig.normlambda,...
    'MeasureProcess', msrProc,...
    ...'MetricProjection', mtrProj,...
    'Dictionary', { synthesizeridnt, analyzeridnt } );

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

%% DMD�\����������
nEps = length(dmdestconfig.epsSet);
rmseNormDmdEst = cell(nEps,1);
t0 = RiverCpsConfig.TsTraining;
tN_1 = RiverCpsConfig.TeTraining;
% �ʐ�250����̌W��
hatXk_1 = PhiX*(exp(omegaX*(tN_1-t0)*60).*bX); 
for iEps = 1:nEps
    % ����̐ݒ�
    mtrProj.release();
    mtrProj.Eps = dmdestconfig.epsSet(iEps);
    rmse_ = zeros(nFrames,1);
    for iFrame = 1:nFrames
        undImg = frameSeq{iFrame};        
        xssrc = undImg(:,:,1); % ���ʂ̊ϑ��f�[�^        
        xbsrc = undImg(:,:,2); % ��ʂ̊ϑ��f�[�^�i�e�X�g�p�j
        stepMonitor.reset();
        stepMonitor.ObservedImage = xssrc;        
        stepMonitor.SourceImage = undImg;
        % �ϑ��f�[�^�̍X�V
        algorithm.release();
        algorithm.Observation = xssrc;
        % ����̍X�V
        hatBk_1 = pinv(PhiX)*hatXk_1(:);
        hatXk = PhiX*(lambdaX.*hatBk_1);
        mtrProj.Center = synthesizeridnt.step(hatXk_1,scalesX);
        algorithm.MetricProjection = mtrProj;
        % ��ʂ𕜌�
        for iter=1:dmdestconfig.maxIter
            [xest,rmseupd] = algorithm.step(); % ��Ԃ̐���f�[�^
            stepMonitor.step(xest);
            if rmseupd < dmdestconfig.tolerr
                break;
            end
        end
        % ��ʂ̐���f�[�^        
        xbest = xest(:,:,2);
        % RMSE��]��
        rmse_(iFrame) = rmse(xbsrc,xbest); 
        % �W���̎擾
        hatXk_1 = algorithm.getCoefficients();        
    end
    rmseNormDmdEst{iEps} = rmse_;    
end

%% �����C���[�h�C�ŗL�l�̓ǂݍ���(CSC-DMD)
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
PhiY = S.PhiY;
lambdaY = S.lambdaY;
omegaY = S.omegaY;
bY = S.bY;
scalesY = S.scalesY;

%% NSOLT���́E�����V�X�e���̃C���X�^���X��
import saivdr.dictionary.nsoltx.NsoltFactory
analyzernsolt    = NsoltFactory.createAnalysis3dSystem(nsolt);
synthesizernsolt = NsoltFactory.createSynthesis3dSystem(nsolt);
analyzernsolt.BoundaryOperation = 'Termination';
synthesizernsolt.BoundaryOperation = 'Termination';

%% �X�p�[�X�M�������̏���(CSC-DMD)
dmdestconfig.cscgamma = RiverCpsConfig.GammaCscDmdEstimation;    
dmdestconfig.csclambda = RiverCpsConfig.LambdaCscDmdEstimation;

% �n�[�h����t��ISTA�X�e�b�v�V�X�e���̃C���X�^���X��
algorithm = IstHcSystem(...
    ...'Observation',    vObs,...
    'DataType', 'Volumetric Data',...
    'Gamma', dmdestconfig.cscgamma,...
    'Lambda',dmdestconfig.csclambda,...
    'MeasureProcess', msrProc,...
    ...'MetricProjection', mtrProj,...
    'Dictionary', { synthesizernsolt, analyzernsolt } );

% �X�e�b�v���j�^�[�V�X�e���̃C���X�^���X��
stepMonitor = StepMonitoringSystem(...
    'DataType','Volumetric Data',...    
    'EvaluationType','double',...
    ...'ImageFigureHandle',hFig3,...
    'IsRMSE',true,...
    'IsMSE',true,...    
    'IsVisible',false,...RiverCpsConfig.IsVisible,...
    'IsVerbose',RiverCpsConfig.IsVerbose);

%% CSC-DMD�\����������
nEps = length(dmdestconfig.epsSet);
rmseCscDmdEst = cell(nEps,1);
% �ʐ�250����̌W��
hatYk_1 = real(PhiY*(exp(omegaY*(tN_1-t0)*60).*bY));
for iEps = 1:nEps
    % ����̐ݒ�
    mtrProj.release();
    mtrProj.Eps = dmdestconfig.epsSet(iEps);
    rmse_ = zeros(nFrames,1);
    for iFrame = 1:nFrames
        undImg = frameSeq{iFrame};
        xssrc = undImg(:,:,1); % ���ʂ̊ϑ��f�[�^
        xbsrc = undImg(:,:,2); % ��ʂ̊ϑ��f�[�^�i�e�X�g�p�j
        stepMonitor.reset();
        stepMonitor.ObservedImage = xssrc;
        stepMonitor.SourceImage = undImg;
        % �ϑ��f�[�^�̍X�V
        algorithm.release();
        algorithm.Observation = xssrc;
        % ����̍X�V
        hatBk_1 = pinv(PhiY)*hatYk_1(:);
        hatYk = real(PhiY*(lambdaY.*hatBk_1));
        mtrProj.Center = synthesizernsolt.step(hatYk_1,scalesY);
        algorithm.MetricProjection = mtrProj;
        % ��ʂ𕜌�
        for iter=1:dmdestconfig.maxIter
            [xest,rmseupd] = algorithm.step(); % ��Ԃ̐���f�[�^
            stepMonitor.step(xest);
            if rmseupd < dmdestconfig.tolerr
                break;
            end
        end
        % ��ʂ̐���f�[�^
        xbest = xest(:,:,2);
        % RMSE��]��
        rmse_(iFrame) = rmse(xbsrc,xbest);
        % �W���̎擾
        hatYk_1 = algorithm.getCoefficients();
    end
    rmseCscDmdEst{iEps} = rmse_;
end

%% DMD�̂�
% �ʐ�250����̌W��
for iFrame = 1:nFrames
    undImg = frameSeq{iFrame};
    xssrc = undImg(:,:,1); % ���ʂ̊ϑ��f�[�^
    xbsrc = undImg(:,:,2); % ��ʂ̊ϑ��f�[�^�i�e�X�g�p�j
    % ��ʂ̐���f�[�^
    tcur = timeSet(iFrame);
    xest = PhiX*(exp(omegaX*(tcur-t0)*60).*bX);
    xest = synthesizeridnt.step(xest,scalesX);        
    xbest = xest(:,:,2);
    % RMSE��]��
    rmse_(iFrame) = rmse(xbsrc,xbest);
end
rmseNormDmdOnly = rmse_;

%% CSC-DMD�̂�
% �ʐ�250����̌W��
for iFrame = 1:nFrames
    undImg = frameSeq{iFrame};
    xssrc = undImg(:,:,1); % ���ʂ̊ϑ��f�[�^
    xbsrc = undImg(:,:,2); % ��ʂ̊ϑ��f�[�^�i�e�X�g�p�j
    % ��ʂ̐���f�[�^
    tcur = timeSet(iFrame);
    yest = real(PhiY*(exp(omegaY*(tcur-t0)*60).*bY));     
    xest = synthesizernsolt.step(yest,scalesY);    
    xbest = xest(:,:,2);
    % RMSE��]��
    rmse_(iFrame) = rmse(xbsrc,xbest);
end
rmseCscDmdOnly = rmse_;

%%
save(fileName,'rmseNormDmdEst','rmseCscDmdEst','rmseNormDmdOnly','rmseCscDmdOnly','dmdestconfig','-append');

%% RMSE�̔�r
markerSet = { 'o', '+', '*', 'x' };

if isVisible
    idxFig = idxFig + 1;
    hFigRmse = figure(idxFig);
    eps_ = dmdestconfig.epsSet;
    for iEps = 1:nEps    
        plot(timeSet,rmseNormDmdEst{iEps},...
            '--','Color',[0.85,0.33,0.10],'Marker',markerSet{iEps},'LineWidth',1,...
            'DisplayName',['Restoration w DMD (\epsilon=' num2str(eps_(iEps)) ')'])
        hold on
        plot(timeSet,rmseCscDmdEst{iEps},...
            '-','Color',[0.47,0.67,0.19],'Marker',markerSet{iEps},'LineWidth',1,...
            'DisplayName',['Restoration w CSC-DMD (\epsilon=' num2str(eps_(iEps)) ')'])
        hold on
    end
    plot(timeSet,rmseNormDmdOnly,...
        ':','Color',[0.93,0.69,0.13],'Marker',markerSet{nEps+1},'LineWidth',1,...
            'DisplayName','DMD Only')
    hold on
    plot(timeSet,rmseCscDmdOnly,...
        '-.','Color',[0.00,0.45,0.74],'Marker',markerSet{nEps+1},'LineWidth',1,...
            'DisplayName','CSC-DMD Only')
    hold on
    %
    xlabel('Time t [min]');
    ylabel('RMSE [m]')
    hFigRmse.Children.LineWidth = 1;
    grid on
    legend('Location','southeast')
    hold off
    print(sprintf('%sbedestrmse',dmdestconfig.dstFolder),'-dpng')        
end
