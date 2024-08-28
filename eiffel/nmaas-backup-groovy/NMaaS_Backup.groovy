package com.ericsson.eiffel.ve.application.model

import com.ericsson.eiffel.ve.api.model.flow.MultiStage
import com.ericsson.eiffel.ve.api.model.Stage
import com.ericsson.eiffel.ve.api.model.VEFlow

import java.util.concurrent.TimeUnit

class NMaaS_Backup extends VEFlow {

    public static final String streamId = "_Stream1" // Replace "Stream1" with Customer name.
    public static final String burId = "_bur1_" // Replace "bur1" with Project name in corespendence with Genie flow.

    public static final String domainId = "eiffeldemo.XAAS_BUR_BACKUP.GENIE_BaselineBuilder" + streamId

    enum BurWorkflowStageType {
        BUR_BDE("", "", ""),
        BUR_CONFIG_BDE("", "", ""),
        BUR_SOLUTION_BDE("", "", ""),

        BUR_BACKUP_CHECK("Backup Check", "Backup_Check", "xaas" + burId + "backup_check"),
        BUR_META("Backup Metadata Export", "Backup_Metadata_DB_Export", "xaas" + burId + "backup_metadata"),
        BUR_PARSER("Parser", "Backup_Parser", "xaas" + burId + "parser"),
        BUR_PRE_CHECKS("PreChecks All WF", "Backup_Pre_Checks_WF", "xaas" + burId + "SWF"),
        BUR_SET_RETENTION("BUR Set Retention", "Backup_Set_Retention", "xaas" + burId + "set_retention"),
        BUR_START_BACKUP("Start Backup", "Backup_Start", "xaas" + burId + "start_backup"),
        BUR_FLAG("Backup Flag Create", "Backup_Success_Flag_Create", "xaas" + burId + "backup_successflag"),
        BUR_BACKUP_VALIDATE("Backup Validate", "Backup_Validate", "xaas" + burId + "backup_validate"),
        BUR_WAIT("Backup Wait", "Backup_Wait", "xaas" + burId + "backup_wait"),
        BUR_NFS_HOUSEKEEPING("NFS Housekeeping", "NFS_dir_Housekeeping", "xaas" + burId + "dirhouse"),
        BUR_OFFSITE_BACKUP("BUR Offsite Backup", "Offsite_Backup", "xaas" + burId + "offsite")

        String stageName, jobInstanceId, confidenceLevel

        BurWorkflowStageType(String stageName, String jobInstanceId, String confidenceLevel) {
            this.stageName =  stageName
            this.jobInstanceId =  "XAAS_BUR_BACKUP." + jobInstanceId + streamId
            this.confidenceLevel =  "eventData.confidenceLevels." + confidenceLevel
        }
    }

    void initFlow() {
        Stage burBdeStage = getStageInstance(BurWorkflowStageType.BUR_BDE)
        Stage burConfigBdeStage = getStageInstance(BurWorkflowStageType.BUR_CONFIG_BDE)
        Stage burSolutionBdeStage = getStageInstance(BurWorkflowStageType.BUR_SOLUTION_BDE)
        Stage burPreChecksStorageStage = getStageInstance(BurWorkflowStageType.BUR_PRE_CHECKS)
        Stage burSetRetentionStage = getStageInstance(BurWorkflowStageType.BUR_SET_RETENTION)
        Stage burStartBackupStage = getStageInstance(BurWorkflowStageType.BUR_START_BACKUP)
        Stage burWaitStage = getStageInstance(BurWorkflowStageType.BUR_WAIT)
        Stage burBackupCheckStage = getStageInstance(BurWorkflowStageType.BUR_BACKUP_CHECK)
        Stage burValidateStage = getStageInstance(BurWorkflowStageType.BUR_BACKUP_VALIDATE)
        Stage burMetaStage = getStageInstance(BurWorkflowStageType.BUR_META)
        Stage burFlagStage = getStageInstance(BurWorkflowStageType.BUR_FLAG)
        Stage burNfsHousekeepingStage = getStageInstance(BurWorkflowStageType.BUR_NFS_HOUSEKEEPING)
        Stage burOffsiteBackupStage = getStageInstance(BurWorkflowStageType.BUR_OFFSITE_BACKUP)

        setStartStage(burSolutionBdeStage)
        addConnection(burBdeStage, burSolutionBdeStage)
        addConnection(burSolutionBdeStage, burPreChecksStorageStage)
        addConnection(burPreChecksStorageStage, burSetRetentionStage)
        addConnection(burSetRetentionStage, burStartBackupStage)
        addConnection(burStartBackupStage, burWaitStage)
        addConnection(burWaitStage, burBackupCheckStage)
        addConnection(burBackupCheckStage, burValidateStage)
        addConnection(burValidateStage, burMetaStage)
        addConnection(burMetaStage, burFlagStage)
        addConnection(burFlagStage, burNfsHousekeepingStage)
        addConnection(burNfsHousekeepingStage, burOffsiteBackupStage)

        //Set max execution duration for flow
        setMaxFlowDuration(TimeUnit.HOURS.toMillis(3))
    }

    String getPluginName() {
        // Name of the plugin is needed for loading the plugins in the VE server.
        return getClass().getSimpleName()
    }

    Stage getStageInstance(BurWorkflowStageType stageType) {
        switch (stageType) {
            case BurWorkflowStageType.BUR_BDE:
                Stage burBdeStage = addStage("EiffelBaselineDefinedEvent", "BUR Baseline", "SUCCESS")
                burBdeStage.addConditions("eventData.baselineName=bur_baseline")
                burBdeStage.addInformationAttribute("BUR Product Version",
                        "eventData.optionalParameters.productSetVersion", "Unknown", Stage.LinkType.none,
                        Stage.DetailsLocation.STAGE_DETAILED)

                return burBdeStage

            case BurWorkflowStageType.BUR_CONFIG_BDE:
                Stage burConfigBdeStage = addStage("EiffelBaselineDefinedEvent", "BUR Config Baseline", "SUCCESS")
                burConfigBdeStage.addConditions("eventData.baselineName=bur_configuration")
                burConfigBdeStage.addInformationAttribute("Customer", "eventData.optionalParameters.CUSTOMER",
                        "Unknown", Stage.LinkType.none, Stage.DetailsLocation.STAGE_OVERVIEW)

                return burConfigBdeStage

            case BurWorkflowStageType.BUR_SOLUTION_BDE:
                Stage burSolutionBdeStage = addStage("EiffelBaselineDefinedEvent", "Master Baseline", "SUCCESS")
                burSolutionBdeStage.addConditions("eventData.baselineName=solutionBaseline")
                burSolutionBdeStage.addConditions("domainId=" + this.domainId)
                burSolutionBdeStage.addInformationAttribute("Flow", "eventTime", "Unknown", Stage.LinkType.dashboardURL)
                burSolutionBdeStage.addInformationAttribute("Deployment Date", "eventTime", "Unknown",
                        Stage.LinkType.none, Stage.DetailsLocation.STAGE_ALL)

                return burSolutionBdeStage

            case BurWorkflowStageType.BUR_PARSER:
            case BurWorkflowStageType.BUR_PRE_CHECKS:
            case BurWorkflowStageType.BUR_SET_RETENTION:
            case BurWorkflowStageType.BUR_START_BACKUP:
            case BurWorkflowStageType.BUR_WAIT:
            case BurWorkflowStageType.BUR_BACKUP_CHECK:
            case BurWorkflowStageType.BUR_BACKUP_VALIDATE:
            case BurWorkflowStageType.BUR_META:
            case BurWorkflowStageType.BUR_FLAG:
            case BurWorkflowStageType.BUR_NFS_HOUSEKEEPING:
            case BurWorkflowStageType.BUR_OFFSITE_BACKUP:
                return getBackupWorkflowStage(stageType)
        }
    }

    Stage getBackupWorkflowStage(BurWorkflowStageType stageType) {
        Stage burStartedStage = addStage("EiffelJobStartedEvent", stageType.stageName + " Started")
        burStartedStage.addConditions("eventData.jobInstance=" + stageType.jobInstanceId)

        Stage burStage = addStage("EiffelConfidenceLevelModifiedEvent", stageType.stageName)
        burStage.addConditions(stageType.confidenceLevel)
        burStage.setStatusKey(stageType.confidenceLevel)
        burStage.addInformationAttribute(stageType.stageName + " Status", stageType.confidenceLevel, "Unknown",
                Stage.LinkType.none, Stage.DetailsLocation.STAGE_OVERVIEW)
        burStage.addInformationAttribute(stageType.stageName + " Log", "eventData.logReferences.consoleLog.uri",
                "Unknown", Stage.LinkType.none, Stage.DetailsLocation.STAGE_DETAILED)

        MultiStage burMultiStage = addMultiStage(stageType.stageName, "Unknown", burStartedStage, burStage)
        burMultiStage.setStatusStage(burStage)

        return burMultiStage
    }
}
