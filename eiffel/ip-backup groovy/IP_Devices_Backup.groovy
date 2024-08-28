package com.ericsson.eiffel.ve.application.model

import com.ericsson.eiffel.ve.api.model.flow.MultiStage
import com.ericsson.eiffel.ve.api.model.Stage
import com.ericsson.eiffel.ve.api.model.VEFlow

import java.util.concurrent.TimeUnit

class IP_Devices_Backup extends VEFlow {

    public static final String domainId = "eiffeldemo.XAAS_BUR_IP.GENIE_BaselineBuilder_ipbackup" 

    enum BurWorkflowStageType {
        IP_SOLUTION_BDE("", "", ""),

        BUR_IP_OFFSITE_BKP("IP Offsite Backup", "IP_Offsite_Backup", "xaas_bur_ipoffsite"),
        BUR_IP_ONSITE_BKP("IP Onsite Backup", "IP_Onsite_Backup", "xaas_bur_iponsite"),

        String stageName, jobInstanceId, confidenceLevel

        BurWorkflowStageType(String stageName, String jobInstanceId, String confidenceLevel) {
            this.stageName =  stageName
            this.jobInstanceId =  "XAAS_BUR_IP." + jobInstanceId
            this.confidenceLevel =  "eventData.confidenceLevels." + confidenceLevel
        }
    }

    void initFlow() {

        Stage burSolutionBdeStage = getStageInstance(BurWorkflowStageType.IP_SOLUTION_BDE)

        Stage burIpOffsiteBkpStage = getStageInstance(BurWorkflowStageType.BUR_IP_OFFSITE_BKP)
        Stage burIpOnsiteBkpStage = getStageInstance(BurWorkflowStageType.BUR_IP_ONSITE_BKP)
        
        setStartStage(burSolutionBdeStage)
        addConnection(burSolutionBdeStage, burIpOffsiteBkpStage)
        addConnection(burIpOffsiteBkpStage, burIpOnsiteBkpStage)
        
        //Set max execution duration for flow
        setMaxFlowDuration(TimeUnit.HOURS.toMillis(3))
    }

    String getPluginName() {
        // Name of the plugin is needed for loading the plugins in the VE server.
        return getClass().getSimpleName()
    }

    Stage getStageInstance(BurWorkflowStageType stageType) {
        switch (stageType) {
            case BurWorkflowStageType.IP_SOLUTION_BDE:
                Stage burSolutionBdeStage = addStage("EiffelBaselineDefinedEvent", "Master Baseline", "SUCCESS")
                burSolutionBdeStage.addConditions("eventData.baselineName=solutionBaseline")
                burSolutionBdeStage.addConditions("domainId=" + this.domainId)
                burSolutionBdeStage.addInformationAttribute("Flow", "eventTime", "Unknown", Stage.LinkType.dashboardURL)
                burSolutionBdeStage.addInformationAttribute("Deployment Date", "eventTime", "Unknown",
                        Stage.LinkType.none, Stage.DetailsLocation.STAGE_ALL)

                return burSolutionBdeStage

            case BurWorkflowStageType.BUR_IP_OFFSITE_BKP:
            case BurWorkflowStageType.BUR_IP_ONSITE_BKP:
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
