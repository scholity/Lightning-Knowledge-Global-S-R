global class BatchKnowledgeGlobalReplace implements Database.Batchable<sObject>, Database.Stateful {
    Private Integer nBatchSize = 100;
    Private String strApexBatchJobId = '';    
    Private String strSearchJobId = '';

    Private String strRecordType = '';
    Private String strPublishStatus = '';
    Private Boolean bPublishNewVersion = false;
    Private String strLanguage = '';
    Private String strChannels = '';
    Private Boolean bMultiLingualKB = false;
    Private Boolean bIsMasterLanguage = true;
    
    Private String strSearchString = '';
    Private String strReplacementString = '';
    Private String strReplacementChannels = '';
    Private String strFieldNames = '';
    
    public Integer UpdateCount = 0;
    public Integer TotalCount = 0;
    public String  strReplacementLog = '';
    
    Private integer nMaxSizePlainTextBody = 16384; // Arbitrary - Have no idea how large the plain text body can be
    
    global BatchKnowledgeGlobalReplace(String strSearchJobId) { 
        this.strSearchJobId = strSearchJobId;
        System.debug('strSearchJobId='+strSearchJobId);
        
        this.strReplacementLog = '';
    } 
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        this.strApexBatchJobId = BC.getJobId();

        String strQuery = 'SELECT Id from KB_Global_Search_And_Replace__c';
        strQuery += ' WHERE Apex_BatchId__c = \''+this.strSearchJobId+'\' ';
        return database.getquerylocator(strQuery);      
    }
   
    global void execute(Database.BatchableContext BC, List<sObject> scope){
        // Record Ids are concatenated to allow all replacement tasks
        // for this batch scope to be returned in a single SOQL query.       
        String strScopeIds = '';
        for (sObject scopeObject : scope) {
            if (strScopeIds.length()>0) strScopeIds += ',';
            strScopeIds += '\''+(String)scopeObject.get('Id')+'\'';
        }        
        
        // Base SOQL construct
        String strQuery = '';
        strQuery += 'SELECT Id, ArticleId__c, KnowledgeArticleId__c, Record_Type__c, ';
        strQuery += ' Language__c, Channels__c, IsMasterLanguage__c, ';   
        strQuery += ' PublishStatus__c, PublishNewVersion__c, ';
        strQuery += ' Search_String__c, Replacement_String__c, Replacement_Channels__c, Field_Names__c '; 
        strQuery += ' FROM KB_Global_Search_And_Replace__c';          
        strQuery += ' WHERE Id IN ('+strScopeIds+')';

        List <sObject> tasks = new List<sObject>();
        tasks = Database.query(strQuery);
        
        try {
            globalReplace(tasks);
        } catch (Exception ex){
            String errMsg = ex.getMessage();
            system.Debug(errMsg);
        } 
    }
    
    public void globalReplace(List<sObject> searchAndReplaceTasks){
        for(sObject task: searchAndReplaceTasks) {
            this.TotalCount++;
            
            String strTaskId = task.Id;
            String strArticleId = (String)task.get('ArticleId__c');
            String strKnowledgeArticleId = (String)task.get('KnowledgeArticleId__c');
            this.strRecordType = (String)task.get('Record_Type__c');
            this.strLanguage = (String)task.get('Language__c'); 
            this.strChannels = (String)task.get('Channels__c');
            this.strFieldNames = (String)task.get('Field_Names__c');
            this.strPublishStatus = (String)task.get('PublishStatus__c');
            this.bPublishNewVersion = Boolean.valueOf((String)task.get('PublishNewVersion__c')); 
            
            this.strSearchString = (String)task.get('Search_String__c');
            this.strReplacementString = (String)task.get('Replacement_String__c');  
            this.strReplacementChannels = (String)task.get('Replacement_Channels__c');   
            
            if(this.strReplacementChannels == null) this.strReplacementChannels = '';
            if(this.strReplacementString == null) this.strReplacementString = '';
                        
            String strIsMasterLanguage = (String)task.get('IsMasterLanguage__c');
            if (!strIsMasterLanguage.equals('NA')) {
                this.bIsMasterLanguage = Boolean.valueOf(strIsMasterLanguage);  
                this.bMultiLingualKB = true;
            } else {
                this.bMultiLingualKB = false;
            }  
            
            List <String> listFieldNames = this.strFieldNames.split(',');
            
            // Create new draft of article to be updated (if required)
            String strDraftId = '';
            String strQuery = '';
            String strArticleNumber = '';
            String strArticleTitle = '';
            
            if (this.strPublishStatus.equals('Online')) {
                // Determine if draft of published article already exists
                strQuery = 'SELECT Id, ArticleNumber, Title';
                strQuery += ' FROM Knowledge__kav';
                strQuery += ' WHERE KnowledgeArticleId = \''+strKnowledgeArticleId +'\' ';
                strQuery += ' AND PublishStatus = \'Draft\' ';
                strQuery += ' AND Language = \''+strLanguage+'\' ';

                List <sObject> listExistingDrafts = Database.query(strQuery); 
                
                if (listExistingDrafts != null && listExistingDrafts.size() >= 1) {
                    strDraftId = listExistingDrafts[0].Id;
                    strArticleNumber = (String)listExistingDrafts[0].get('ArticleNumber');
                    strArticleTitle = (String)listExistingDrafts[0].get('Title');
                    
                    this.strPublishStatus = 'Draft';
                    strReplacementLog += 'Draft exists for article '+strArticleNumber+' Title='+strArticleTitle+' Language='+strLanguage+' (will be kept as Draft)\n';   
                } else {
                    if (bMultiLingualKB && !bIsMasterLanguage) {
                        strDraftId = KbManagement.PublishingService.editPublishedTranslation(strKnowledgeArticleId, strLanguage, false);                    
                    } else {
                        strDraftId = KbManagement.PublishingService.editOnlineArticle(strKnowledgeArticleId, false);
                    } 
                }
            } else {
                strDraftId = strArticleId;
            }

            // Get new (or existing) draft of article
            strQuery = 'SELECT ArticleNumber';
            // Insure Title is retrieved to allow for audit trail reporting
            if (this.strFieldNames.toLowerCase().indexOf('title')<0) strQuery += ', Title';
            // Add search/replacement fields
            strQuery += ','+this.strFieldNames;
            // Add channels if replacement requested
            if (this.strReplacementChannels.length()>0) strQuery += ',IsVisibleInPrm,IsVisibleInCsp,IsVisibleInPkb';
            strQuery += ' FROM Knowledge__kav';
            strQuery += ' WHERE Id = \''+strDraftId+'\'';
           
            List <sObject> listDrafts;
            try {
                listDrafts = Database.query(strQuery);
            } catch (Exception ex){
                String errMsg = ex.getMessage();
                system.Debug(errMsg);
            }               
         
            // Iterate through fields and perform string or channel replacement(s)
            if (listDrafts != null && listDrafts.size() == 1) {
                sObject draft = listDrafts[0];
                
                strArticleNumber = (String)draft.get('ArticleNumber');
                strArticleTitle = (String)draft.get('Title');
                
                //this.strSearchString = (String)task.get('Search_String__c');
                //this.strReplacementString = (String)task.get('Replacement_String__c');
                
                System.debug('*** Batch Knowledge Global Replace *** Search String='+this.strSearchString);
                System.debug('*** Batch Knowledge Global Replace *** Replacement String='+this.strReplacementString);
                
                if (this.strReplacementChannels.length()>0) {
                    // Reset/Set Channels as Specified in Replacement Channels String                
                    String strChannel = '';
                    String strChannelCodes = '';
                    for (Integer index=0; index<this.strReplacementChannels.length(); index++) {
                        strChannel = this.strReplacementChannels.substring(index,index+1);
                        // Internal channel is ALWAYS set true (uneditable via API)
                        //if (strChannel.equalsIgnoreCase('I')) {draft.put('IsVisibleInApp',true);strChannelCodes+='I';}
                        if (strChannel.equalsIgnoreCase('C')) {draft.put('IsVisibleInCsp',true);strChannelCodes+='C';}  
                        if (strChannel.equalsIgnoreCase('P')) {draft.put('IsVisibleInPrm',true);strChannelCodes+='P';}
                        if (strChannel.equalsIgnoreCase('K')) {draft.put('IsVisibleInPkb',true);strChannelCodes+='K';}
                    }

                    //if (strChannel.positionOf('I')<0) draft.put('IsVisibleInApp',false); Internal channel is ALWAYS set true (uneditable via API)
                    if (strChannelCodes.indexOf('C')<0) draft.put('IsVisibleInCsp',false);
                    if (strChannelCodes.indexOf('P')<0) draft.put('IsVisibleInPrm',false);
                    if (strChannelCodes.indexOf('K')<0) draft.put('IsVisibleInPkb',false);
                                                            
                    System.debug('*** Batch Knowledge Global Replace *** Channels='+strChannelCodes);
                } else {
                    String strRegEx = this.strSearchString;
                    Pattern strSearchStringPattern = Pattern.compile(strRegEx);
                                  
                    for (String strFieldName: listFieldNames) {
                        String strFieldValue = (String)draft.get(strFieldName);
                        
                        System.debug('*** Batch Knowledge Global Replace *** Field Name='+strFieldName);
                        System.debug('*** Batch Knowledge Global Replace *** Field Value='+strFieldValue);
                        
                        Matcher matcher = strSearchStringPattern.matcher(strFieldValue);
                        draft.put(strFieldName, matcher.replaceAll(this.strReplacementString));
                        
                        System.debug('*** Batch Knowledge Global Replace *** Field='+strFieldName+' New Value='+draft.get(strFieldName));
                    }
                }
                
                Database.SaveResult results;
                try {
                    this.UpdateCount++;
                    results = Database.update(draft);
                } catch (Exception ex){
                    String errMsg = ex.getMessage();
                    system.Debug(errMsg);
                }                   
                        
                // Republish updated Draft article (if article was originally published)
                if (results.isSuccess()) {
                    if (strPublishStatus.equals('Online')) {
                        if (bMultiLingualKB && !bIsMasterLanguage) {
                            // Mark translation as complete - this actually publishes the translation
                            KbManagement.PublishingService.completeTranslation(strDraftId);  
                        } else {                        
                            KbManagement.PublishingService.publishArticle(strKnowledgeArticleId, bPublishNewVersion);
                        } 
                        
                        strReplacementLog += 'Modified and republished article '+strArticleNumber+' Title='+strArticleTitle+' Language='+strLanguage+'\n';                          
                    } else {
                        strReplacementLog += 'Modified and retained draft article '+strArticleNumber+' Title='+strArticleTitle+' Language='+strLanguage+'\n';
                    }
                } else {
                    strReplacementLog += 'Unable to update draft article '+strArticleNumber+' Title='+strArticleTitle+' Language='+strLanguage+'\n';
                }
            } 
        }
    }
    
    
    global void finish(Database.BatchableContext BC){
        // Clean up - Delete all replacement tasks records from work queue
        List <KB_Global_Search_And_Replace__c> listGSR = [select Id from KB_Global_Search_And_Replace__c where Apex_BatchId__c = :this.strSearchJobId];
        try {
            Database.delete(listGSR);  
        } catch (Exception ex){
            String errMsg = ex.getMessage();
            system.Debug(errMsg);
        } 
        
        String strQuery = '';
        List<KB_Global_Search_History__c> listSearchStatus = new List<KB_Global_Search_History__c>();
        
        strQuery += 'SELECT Id, Articles_Searched__c, Articles_Updated__c';
        strQuery += ' FROM KB_Global_Search_History__c';
        strQuery += ' WHERE Apex_Replacement_BatchId__c LIKE \'%'+this.strApexBatchJobId.substring(0,15)+'%\' ';
        
        try {
            listSearchStatus = Database.query(strQuery);     
        } catch (Exception ex){
            String errMsg = ex.getMessage();
            system.Debug(errMsg);
        }                   

        if (listSearchStatus != null && listSearchStatus.size() > 0) {
            KB_Global_Search_History__c searchStatus = listSearchStatus[0];
            
            searchStatus.Articles_Updated__c = this.UpdateCount;
            searchStatus.Replacement_Log__c = this.strReplacementLog;
            this.TotalCount = Integer.valueOf(searchStatus.Articles_Searched__c);
            
            try {
                Database.update(searchStatus);
            } catch (Exception ex){
                String errMsg = ex.getMessage();
                system.Debug(errMsg);
            }               
        }
                                
        // Query the AsyncApexJob object to retrieve the current job's metadata.
        AsyncApexJob a = [SELECT Id, Status, NumberOfErrors, JobItemsProcessed,
           TotalJobItems, CreatedBy.Email FROM AsyncApexJob WHERE Id = :this.strApexBatchJobId];             
           
        // Email the Batch Job's submitter that the Job is finished.
        if (strReplacementLog.length()>nMaxSizePlainTextBody) {
            strReplacementLog = strReplacementLog.substring(0,nMaxSizePlainTextBody) + '...truncated';
        }
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new String[] {a.CreatedBy.Email};
        mail.setToAddresses(toAddresses);
        mail.setSubject('Salesforce Knowledge Global Search and Replace-Replacement Complete');
        mail.setPlainTextBody(
         'Record Type='+this.strRecordType+'\n'+
         'Publish Status='+this.strPublishStatus+'\n'+
         'Search Fields='+this.strFieldNames+'\n'+
         'Search String='+this.strSearchString+'\n'+
         'Replacement String='+this.strReplacementString+'\n\n\n'+
         'Total number of articles searched='+this.TotalCount+'\n'+
         'Total number of articles updated='+this.UpdateCount+'\n\n\n'+
         'Salesforce.com Job Statistics:\n'+
         'Number of Errors='+a.NumberOfErrors+'\n'+
         'Status='+a.Status+'\n\n'+
         'Replacement Log:'+'\n'+
         strReplacementLog         
         );
          
          
        if (!Test.isRunningTest()) {
            // Disable outbound email for now
            //Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
}