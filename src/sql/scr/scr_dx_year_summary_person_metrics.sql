with 
person as (select * from `som-rit-phi-oncology-prod.oncology_omop_arpah_alpha.person`),
concept as (select * from `som-rit-phi-starr-prod.starr_omop_cdm5_latest.concept`),
scr as (select * from `som-rit-phi-oncology-dev.onc_farnoosh_oncology_common.onc_neuralframe_case_diagnoses`),
scr_patients as
  (
    select
    distinct
        cast(nf.dateofbirth as date format 'yyyymmdd') as date_of_birth,
        if(
                length(nf.medicalrecordnumber) <= 8,
                lpad(nf.medicalrecordnumber, 8, '0'),
                lpad(nf.medicalrecordnumber, 10, '0')
        ) as cleaned_mrn
        ,nf.*
        ,case 
  when primarySite is not null and histologicTypeIcdO3 is not null and behaviorCodeIcdO3 is not null then
    concat(histologicTypeIcdO3,'/',behaviorCodeIcdO3,'-',concat(substr(primarySite,1,3),'.',substr(primarySite,4,1) )) 
  when primarySite is not null and histologicTypeIcdO3 is null and behaviorCodeIcdO3 is null then
    concat('NULL-',concat(substr(primarySite,1,3),'.',substr(primarySite,4,1) ))
end dx_concept_code 
    from
    scr nf
    where
    length(trim(nf.dateOfBirth)) = 8
),
cancer_disease_group as
(
SELECT
distinct
    source.concept_code icdo3_concept_code
    ,source.concept_name icdo3_concept_name
FROM concept source
where source.vocabulary_id = 'ICDO3'
and length(source.concept_code) = 3
and source.concept_code like 'C%'
),
unique_dx_concept_codes as
(
  select 
distinct
histologicTypeIcdO3,
behaviorCodeIcdO3,
primarySite,
case 
  when primarySite is not null and histologicTypeIcdO3 is not null and behaviorCodeIcdO3 is not null then
    concat(histologicTypeIcdO3,'/',behaviorCodeIcdO3,'-',concat(substr(primarySite,1,3),'.',substr(primarySite,4,1) )) 
  when primarySite is not null and histologicTypeIcdO3 is null and behaviorCodeIcdO3 is null then
    concat('NULL-',concat(substr(primarySite,1,3),'.',substr(primarySite,4,1) ))
end concept_code
from scr
where case 
  when primarySite is not null and histologicTypeIcdO3 is not null and behaviorCodeIcdO3 is not null then
    concat(histologicTypeIcdO3,'/',behaviorCodeIcdO3,'-',concat(substr(primarySite,1,3),'.',substr(primarySite,4,1) )) 
  when primarySite is not null and histologicTypeIcdO3 is null and behaviorCodeIcdO3 is null then
    concat('NULL-',concat(substr(primarySite,1,3),'.',substr(primarySite,4,1) ))
end is not null
),
dx_name as 
(
  select 
  distinct
  c.concept_code,
  c.concept_name
  from concept c
    join unique_dx_concept_codes dx on dx.concept_code = c.concept_code
where c.vocabulary_id = 'ICDO3' and c.domain_id = 'Condition'
),
scr_dx_omop as
(
select distinct
ep.person_source_value,
sp.*,
dg.icdo3_concept_code primary_site_group_code,
dg.icdo3_concept_name primary_site_group_name,
dx_name.concept_code dx_concept_code,
dx_name.concept_name dx_name
from
scr_patients sp
join person ep on concat(FORMAT('%s | %s', cleaned_mrn,
    cast(date_of_birth as string format 'yyyy-mm-dd'))) = ep.person_source_value
left join cancer_disease_group dg on substr(sp.primarySite,1,3) = dg.icdo3_concept_code
left join dx_name on sp.dx_concept_code = dx_name.concept_code
)
select 
substr(dateofdiagnosis,1,4) scr_dx_year,
count(distinct person_source_value) patient_count
from 
scr_dx_omop
group by scr_dx_year
order by scr_dx_year desc
