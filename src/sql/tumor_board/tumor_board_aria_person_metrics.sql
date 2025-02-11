with
person as (select * from `som-rit-phi-oncology-prod.oncology_omop_arpah_alpha.person`),
pat_enc as (select * from `som-rit-phi-starr-prod.shc_clarity_filtered_latest.pat_enc`),
zc_disp_enc_type as (select * from `som-rit-phi-starr-prod.shc_clarity_filtered_latest.zc_disp_enc_type`),
clarity_prc as (select * from `som-rit-phi-starr-prod.shc_clarity_filtered_latest.clarity_prc`),
patient as (select * from `som-rit-phi-starr-prod.shc_clarity_filtered_latest.patient`),
aria_patient as (select * from `som-rit-phi-oncology-prod.oncology_aria_raw.patient`),
aria_patients as
(
  select
  distinct
  patientid,
  extract(date from dateofbirth) dateofbirth
  from
  aria_patient
),
tumor_board_patients AS (
SELECT
  DISTINCT p.pat_mrn_id,
  extract(date from p.birth_date) birth_date
FROM
  pat_enc enc -- this is only getting tumor board patients from shc, not lpch, is that an issue?
  left join zc_disp_enc_type et on enc.enc_type_c=et.disp_enc_type_c
  left join clarity_prc on enc.appt_prc_id = clarity_prc.prc_id
  inner join patient p on enc.pat_id=p.pat_id
  where
    (appt_status_c IS NULL OR appt_status_c = 2) --encounter is not marked as cancelled
    and (et.name IS NULL or et.name != 'Erroneous Encounter') --encounter is not labeled as erroneous
  and (
    UPPER(clarity_prc.prc_name) IN ("DISCUSSION ONLY TUMOR BOARD", "IN PERSON TUMOR BOARD", "TUMOR BOARD", "TUMOR BOARD LIVER") -- visit type (aka appt_prc_id) of tumor board
    or et.name = 'Tumor Board' --enc_type of tumor board
  )
)
select count(distinct person.person_source_value) patient_count
from
tumor_board_patients tb
inner join person on person.person_source_value = CONCAT(FORMAT('%s | %s', tb.pat_mrn_id, CAST(cast(tb.birth_date AS date) AS string format 'yyyy-mm-dd')))
inner join aria_patients ap on person.person_source_value = concat(FORMAT('%s | %s', ap.patientid, cast(ap.dateofbirth as string format 'yyyy-mm-dd')))
