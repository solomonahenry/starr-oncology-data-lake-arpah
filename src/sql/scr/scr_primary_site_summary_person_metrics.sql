with
person as (select * from `som-rit-phi-oncology-prod.oncology_omop_arpah_alpha.person`),
scr as (select * from `som-rit-phi-oncology-prod.oncology_neuralframe_raw.neuralframe_parquet_registry_data`),
scr_data as
(
select
distinct
IF(LENGTH(medicalRecordNumber) <= 8, LPAD(medicalRecordNumber, 8, '0'), LPAD(medicalRecordNumber, 10, '0')) as cleaned_mrn
,cast(dateOfBirth as date format 'yyyymmdd') as dateOfBirth
,primarySite
,primarySiteDescription
,MIN(dateOfDiagnosis) as earliest_scr_diagnosis_date --note: not all patients have a SCR diagnosis date
from
scr nf
where
trim(medicalRecordNumber) <> ''and length(dateOfBirth) = 8
group by cleaned_mrn,dateOfBirth,primarySite,primarySiteDescription
),
scr_omop as
(select
 distinct
 p.person_id,
 p.person_source_value,
 primarySite,
 primarySiteDescription,
 scr_data.earliest_scr_diagnosis_date
from
scr_data
join person p on p.person_source_value = CONCAT(scr_data.cleaned_mrn, ' | ', scr_data.dateOfBirth)
)
select
primarySite, primarysiteDescription,
count(distinct person_source_value) patient_count
from scr_omop
where primarySite is not null
group by primarySite,primarysiteDescription
order by primarySite
-- icdo code distribution 