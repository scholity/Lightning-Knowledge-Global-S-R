public with sharing class KB_Global_Search_and_Replace {
    Public Integer nArticlesWithLinksCount {get;set;}
    Public Transient List<SObject> kav {get;set;}

    Public String[] strRecordTypes {get;set;}
    Public Map<String, String> mapRecordType;
    Public String strPublishStatus {get;set;}
    Public String strLanguage {get;set;}
    Public String[] strChannels {get;set;}

    Public String[] strFields {get;set;}
    Public String strSearchFields {get;set;}
    
    Public String strSearchString {get;set;}
    Public String strReplacementString {get;set;}
    Public String strReplacementChannels {get;set;}
    Public String strReplacementLog {get;set;}
    
    Public String strApexBatchId {get;set;}
    Public Decimal nArticlesSearched {get;set;}
    Public Decimal nArticlesSelected {get;set;}
    Public Decimal nArticlesUpdated {get;set;}    
    Public String strSearchStatus {get;set;}
    
    Public Boolean bSearchOnly {get;set;}
    Public Boolean bEnableRegex {get;set;}
    Public Boolean bCaseSensitive {get;set;}
    Public Boolean bPublishNewVersion {get;set;}    
    Public Boolean bMultiLingualKB;
    Public Boolean bProcessing {get;set;}

    //builds a picklist of record types
    public List<selectOption> getRecordTypes() {
        List<selectOption> options = new List<selectOption>(); 
        options.add(new selectOption('None', 'Select a Record Type'));
        options.add(new selectOption('All', 'All'));  
        this.mapRecordType.put('All', 'All');
        
        String queryPublishStatus = 'Draft';
        String queryLanguage = 'en_US';
        
        String strQuery = '';
        strQuery += 'SELECT KnowledgeRecordTypeId__c FROM Knowledge__kav ';
        strQuery += 'WHERE PublishStatus = \''+queryPublishStatus+'\' ';
        strQuery += 'AND Language = \''+queryLanguage+'\' ';
        strQuery += 'Group By KnowledgeRecordTypeId__c ';  
        
        List<AggregateResult> queryResult = Database.query(strQuery);
        List<String> knowledgeRecordTypeIds = new List<String>();
        for (AggregateResult theQueryResult: queryResult) {
            knowledgeRecordTypeIds.add((String)theQueryResult.get('KnowledgeRecordTypeId__c'));
        }      
        
        List<RecordType> recordTypes = [Select Id, Name From RecordType Where Id In :knowledgeRecordTypeIds];

        for (RecordType theRecordType: recordTypes) {
        	String strRecordTypeId = (String)theRecordType.Id;
        	if (strRecordTypeId.length() > 15) strRecordTypeId = strRecordTypeId.substring(0,15);
        	
            options.add(new selectOption(strRecordTypeId, theRecordType.Name));
            this.mapRecordType.put(strRecordTypeId, theRecordType.Name);
        }
                                        
        return options; 
    } 
    
    //builds a picklist of publish statuses
    public List<selectOption> getPublishStatus() {
        List<selectOption> options = new List<selectOption>(); 
        options.add(new selectOption('Draft', 'Draft')); 
        options.add(new selectOption('Online', 'Published')); 
        //options.add(new selectOption('Archived', 'Archived')); 
                                        
        return options; 
    }     
    
    // Builds a picklist of language codes
    public List<selectOption> getLanguage() {
        // Derive list of active knowledge langauges from KnowledgeArticle object
        Schema.Describefieldresult describeLanguage = KnowledgeArticleVersion.fields.Language.getDescribe();
        List<Schema.PicklistEntry> listLanguage = describeLanguage.getPicklistValues();
        
        if (listLanguage.size() > 1) bMultiLingualKB = true;

        List<selectOption> options = new List<selectOption>(); 
        // Search for default Language, force to top of list if present
        String strDefaultLanguage = '';
        for (Schema.PicklistEntry pe: listLanguage) {
            if (pe.isActive() && pe.isDefaultValue()) {
                options.add(new selectOption(pe.getValue(), '***'));
                strDefaultLanguage = pe.getValue();
                break;
            }
        }           
        for (Schema.PicklistEntry pe: listLanguage) {
            if (pe.isActive() && !(pe.getValue().equals(strDefaultLanguage))) {
                options.add(new selectOption(pe.getValue(), pe.getLabel()));
            }
        }        
                             
        return options; 
    }     
     
    //builds a picklist of channels
    public List<selectOption> getChannels() {
        List<selectOption> options = new List<selectOption>(); 
        //options.add(new selectOption('application','Internal'));
        options.add(new selectOption('csp','Customer')); 
        options.add(new selectOption('prm','Partner')); 
        options.add(new selectOption('sites','Public'));                                         
        return options; 
    }    
     
    public List<SelectOption> getArticleFields() {
        //if (this.strRecordTypes == null) return null;
        
        /*
        sObject sObjArticleType = Schema.getGlobalDescribe().get(strRecordType).newSObject();
        Schema.DescribeSObjectResult descArticleType = sObjArticleType.getSObjectType().getDescribe();
        Map<String, Schema.SObjectField> mapArticleTypeFields = descArticleType.fields.getMap(); 
        */  
        
        List<SelectOption> options = new List<SelectOption>();
        options.add(new selectOption('All', 'All'));          
        
        String knowledgeObjectName = 'Knowledge__kav';  
	    Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(knowledgeObjectName).getDescribe().fields.getMap();
	    for (String fieldName: fieldMap.keySet()) {  
	    	if (fieldMap.get(fieldName).getDescribe().getType() == Schema.DisplayType.String ||
	    		fieldMap.get(fieldName).getDescribe().getType() == Schema.DisplayType.TextArea) {
	    		if ('urlname,articlenumber,knowledgerecordtypeid__c'.contains(fieldName.toLowerCase())) continue;
	        	options.add(new SelectOption(fieldName, fieldMap.get(fieldName).getDescribe().getLabel())); 
	    	}
	    }             
    

        /*    
        Set<String> setFieldNames = mapArticleTypeFields.keySet();
        for (String strFieldName : setFieldNames) {
            Schema.DescribeFieldResult descSObjectField = mapArticleTypeFields.get(strFieldName).getDescribe();
        
            if (descSObjectField.getType() == Schema.DisplayType.String
                || descSObjectField.getType() == Schema.DisplayType.TextArea) {
                
                // Toss out all unsupported (internal or metadata) text fields
                String strFieldNameLC = strFieldName.toLowerCase();
                
                if (strFieldNameLC.equals('urlname'))continue;
                if (strFieldNameLC.equals('articlenumber')) continue;
                if (strFieldNameLC.endsWith('name__s')) continue; // FILE field type label (field__name__s)
                
                options.add(new SelectOption(strFieldName, descSObjectField.getLabel()));                  
            }
        }
        */
        
        return options;
    }
     
    public KB_Global_Search_and_Replace() {
        bSearchOnly = false;
        bEnableRegex = false;
        bCaseSensitive = false;
        bPublishNewVersion = true;
        bMultiLingualKB = false;
        bProcessing = false;

        this.strFields = new String[]{};
        if (strSearchString == null) strSearchString = '';
        
        this.strSearchStatus = 'Waiting for User Input';
        this.nArticlesSearched = 0;
        this.nArticlesSelected = 0;
        this.nArticlesUpdated = 0;      
        
        this.strRecordTypes = new String[] {'None'};
        this.mapRecordType = new Map<String,String>();
        this.strLanguage = 'en_US';
        this.strChannels = new String[] {'application'};
        this.strReplacementChannels = '';
    }
        
    public void performSearch() {
        if (!Test.isRunningTest()) {
            strSearchFields = '';
            for (String strFieldSelection : strFields) {
                if (strSearchFields.length()>0) strSearchFields += ',';
                strSearchFields += strFieldSelection;
            }           
        } else {      
            strSearchFields = 'Title';          
        }
        
        if (!(strSearchFields.length()>0)) {
            ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR,'No Search Field(s) Selected');
            ApexPages.AddMessage(msg);          
        } else {
            String strRegexString = strSearchString;
            if (!strRegexString.equals('*')) {
                if (!bEnableRegex) strRegexString = '\\Q'+strRegexString+'\\E';
                if (!bCaseSensitive) strRegexString = '(?i)'+strRegexString;
            } else {
                strRegexString = '.*';
            }
            
            // Enhancement ENH01
            // 10-05-2017 (SJC) - Disable auto-verification of batch job status.
            // Search and replace job will be enqueued regardless of number of outstanding batch requests.
            // This implies that resources for the S&R job will be assigned at some unknown point in future
            
            /* ENH01
            Integer nActiveBatchJobs = [select count() from AsyncApexJob where JobType = 'BatchApex' and status in ('Queued','Processing','Preparing')];
    
            if(nActiveBatchJobs > 4){
                ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.ERROR,'Maximum of 5 Active Batch Jobs Allowed');
                ApexPages.AddMessage(msg);
                this.strSearchStatus = 'System Busy - Please try your request later';            
            } else { 
            
            */       
                if (strReplacementString == null) strReplacementString = '';
                if (strReplacementChannels == null) strReplacementChannels = '';    
                              
                BatchKnowledgeGlobalSearch batch =
                new BatchKnowledgeGlobalSearch(bSearchOnly, bPublishNewVersion, bMultiLingualKB,
                    strRecordTypes, mapRecordType, strPublishStatus, strLanguage, strChannels,
                    strSearchFields, strRegexString, strReplacementString, strReplacementChannels);
                if (!Test.isRunningTest()) {        
                    try {
                        this.strApexBatchId = Database.executeBatch(batch, 500);
                        this.strSearchStatus = 'Searching...';  
                        this.bProcessing = true;          
                    } catch (Exception ex){
                        String errMsg = ex.getMessage();
                        system.Debug('*** KB Global Search and Replace *** - Exception:'+errMsg);
                        this.strSearchStatus = 'System Busy - Please try your request later';
                    } 
                }
            // } ENH01
        }
        
        this.nArticlesSearched = 0;
        this.nArticlesSelected = 0;
        this.nArticlesUpdated = 0;          
    }
          
    public void refresh() {
        String strQuery = '';
        System.debug('this.strApexBatchId='+this.strApexBatchId);
        List<KB_Global_Search_History__c> listSearchHistory = new List<KB_Global_Search_History__c>();
        
        strQuery += 'SELECT Articles_Searched__c, Articles_Selected__c, Articles_Updated__c, Apex_Replacement_BatchId__c, Replacement_Log__c';
        strQuery += ' FROM KB_Global_Search_History__c';
        strQuery += ' WHERE Apex_BatchId__c LIKE \'%'+this.strApexBatchId+'%\' ';
        
        listSearchHistory = Database.query(strQuery);
        
        /*
        [SELECT Articles_Searched__c,
            Articles_Selected__c, Articles_Updated__c, Apex_Replacement_BatchId__c
            FROM KB_Global_Search_History__c WHERE Apex_BatchId__c LIKE '%:this.strApexBatchId%'];
        */
        
        if (listSearchHistory != null && listSearchHistory.size() >0) {
                
            this.strSearchStatus = 'Search Complete';
            
            this.nArticlesSearched = listSearchHistory[0].Articles_Searched__c;
            this.nArticlesSelected = listSearchHistory[0].Articles_Selected__c; 
            this.nArticlesUpdated  = listSearchHistory[0].Articles_Updated__c;
            this.strReplacementLog  = listSearchHistory[0].Replacement_Log__c;
            String replacementJobId = listSearchHistory[0].Apex_Replacement_BatchId__c;
            
            if (!bSearchOnly) {
                if (replacementJobId.equals('Not Executed')) {
                    this.strSearchStatus+='-Replacement Not Executed';
                    this.bProcessing = false;
                } else {
                    strQuery = '';
                    List<AsyncApexJob> jobList = new List<AsyncApexJob>();
                    strQuery += 'SELECT Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems';
                    strQuery += ' FROM AsyncApexJob';
                    strQuery += ' WHERE Id =\''+replacementJobId+'\' ';
                    
                    jobList = Database.query(strQuery);            
                    
                    if (jobList != null && jobList.size()>0) {
                        AsyncApexJob job = jobList[0];
                        /*[Select Id, Status, NumberOfErrors, JobItemsProcessed, TotalJobItems 
                              from AsyncApexJob where Id =:replacementJobId];     */
                        if (job.Status.equals('Processing')) {
                            this.strSearchStatus+='-Replacement Pending';
                            this.bProcessing = true;  
                        }        
                        if (job.Status.equals('Completed')) {
                            this.strSearchStatus+='-Replacement Complete'; 
                            this.bProcessing = false;
                        }
                    }  
                }
            } else {
                this.bProcessing = false;
            }           
        }        
    }
}