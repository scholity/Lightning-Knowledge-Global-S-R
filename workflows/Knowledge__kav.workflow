<?xml version="1.0" encoding="UTF-8"?>
<Workflow xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldUpdates>
        <fullName>Copy_Knowledge_RecordTypeId</fullName>
        <field>KnowledgeRecordTypeId__c</field>
        <formula>RecordTypeId</formula>
        <name>Copy Knowledge RecordTypeId</name>
        <notifyAssignee>false</notifyAssignee>
        <operation>Formula</operation>
        <protected>false</protected>
    </fieldUpdates>
    <rules>
        <fullName>Set Knowledge Record Type Id</fullName>
        <actions>
            <name>Copy_Knowledge_RecordTypeId</name>
            <type>FieldUpdate</type>
        </actions>
        <active>true</active>
        <formula>1==1</formula>
        <triggerType>onAllChanges</triggerType>
    </rules>
</Workflow>
