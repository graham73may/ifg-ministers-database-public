SELECT
    CASE
        -- Acting and appointment starts before start of chart range
        WHEN MAX(CASE WHEN q.is_acting = 1 THEN 1 ELSE 0 END) = 1 AND STRFTIME('%Y', MIN(q.start_date)) < STRFTIME('%Y', @start_date) THEN MIN(q.minister_short_name) || ' (acting - since ' || STRFTIME('%Y', MIN(q.start_date)) || ')'
        WHEN MAX(CASE WHEN q.is_acting = 1 THEN 1 ELSE 0 END) = 1 AND MIN(q.start_date) < @start_date THEN MIN(q.minister_short_name) || ' (acting - since ' || SUBSTR("--JanFebMarAprMayJunJulAugSepOctNovDec", STRFTIME ("%m", MIN(q.start_date)) * 3, 3) || ' ' || STRFTIME('%Y', MIN(q.start_date)) || ')'

        -- Acting and appointment ends after end of chart range
        WHEN MAX(CASE WHEN q.is_acting = 1 THEN 1 ELSE 0 END) = 1 AND STRFTIME('%Y', MAX(q.end_date)) > STRFTIME('%Y', @end_date) THEN MIN(q.minister_short_name) || ' (acting - until ' || STRFTIME('%Y', MAX(q.end_date)) || ')'
        WHEN MAX(CASE WHEN q.is_acting = 1 THEN 1 ELSE 0 END) = 1 AND MAX(q.end_date) > @end_date THEN MIN(q.minister_short_name) || ' (acting - until ' || SUBSTR("--JanFebMarAprMayJunJulAugSepOctNovDec", STRFTIME ("%m", MIN(q.end_date)) * 3, 3) || ' ' || STRFTIME('%Y', MAX(q.end_date)) || ')'

        -- Acting
        WHEN MAX(CASE WHEN q.is_acting = 1 THEN 1 ELSE 0 END) = 1 THEN MIN(q.minister_short_name) || ' (acting)'

        -- Appointment starts before start of chart range
        WHEN STRFTIME('%Y', MIN(q.start_date)) < STRFTIME('%Y', @start_date) THEN MIN(q.minister_short_name) || ' (since ' || STRFTIME('%Y', MIN(q.start_date)) || ')'
        WHEN MIN(q.start_date) < @start_date THEN MIN(q.minister_short_name) || ' (since ' || SUBSTR("--JanFebMarAprMayJunJulAugSepOctNovDec", STRFTIME ("%m", MIN(q.start_date)) * 3, 3) || ' ' || STRFTIME('%Y', MIN(q.start_date)) || ')'

        -- Appointment ends after end of chart range
        WHEN STRFTIME('%Y', MAX(q.end_date)) > STRFTIME('%Y', @end_date) THEN MIN(q.minister_short_name) || ' (until ' || STRFTIME('%Y', MAX(q.end_date)) || ')'
        WHEN MAX(q.end_date) > @end_date THEN MIN(q.minister_short_name) || ' (until ' || SUBSTR("--JanFebMarAprMayJunJulAugSepOctNovDec", STRFTIME ("%m", MIN(q.end_date)) * 3, 3) || ' ' || STRFTIME('%Y', MAX(q.end_date)) || ')'

        -- Normal case
        ELSE MIN(q.minister_short_name)

    END label,
    'gender-' || LOWER(REPLACE(REPLACE(MIN(q.gender), ' ', '-'), '.', '')) gender,
    'party-' || LOWER(REPLACE(REPLACE(MIN(q.party), ' ', '-'), '.', '')) party,
    MIN(q.start_date) "start",
    COALESCE(MAX(q.end_date), DATE('now')) "end"
FROM (
    SELECT
        ROW_NUMBER() OVER (PARTITION BY person_id, appointment_characteristics_id ORDER BY continues_previous_appointment DESC, group_name) ROW_NUMBER,
        *
    FROM (
        SELECT
            CASE
                WHEN LAG(ac.end_date) OVER (PARTITION BY pr.group_name ORDER BY ac.start_date ASC) = ac.start_date THEN 1
                ELSE 0
            END continues_previous_appointment,
            pr.group_name,
            CASE
                WHEN ol1.id IS NULL AND ol2.id IS NULL THEN RANDOM()
                WHEN ol1.id IS NULL THEN ol2.id
                WHEN ol2.id IS NULL THEN ol1.id
            END organisation_link_id,
            p.id person_id,
            p.id,
            p.name minister_name,
            p.short_name minister_short_name,
            p.gender,
            CASE
                WHEN r.house = 'Commons' THEN 'MP'
                WHEN r.house = 'Lords' THEN 'Peer'
            END "MP/peer",
            rc.party,
            t.name post_name,
            t.rank_equivalence,
            o.short_name org_name,
            ac.id appointment_characteristics_id,
            ac.cabinet_status,
            ac.is_on_leave,
            ac.is_acting,
            ac.leave_reason,
            ac.start_date,
            ac.end_date
        FROM appointment a
            INNER JOIN appointment_characteristics ac ON
                a.id = ac.appointment_id
            INNER JOIN person p ON
                a.person_id = p.id AND
                COALESCE(a.start_date, '1900-01-01') >= COALESCE(p.start_date, '1900-01-01') AND
                COALESCE(a.start_date, '1900-01-01') < COALESCE(p.end_date, '9999-12-31')
            LEFT JOIN representation r ON
                a.person_id = r.person_id AND
                COALESCE(a.start_date, '1900-01-01') >= COALESCE(r.start_date, '1900-01-01') AND
                COALESCE(a.start_date, '1900-01-01') < COALESCE(r.end_date, '9999-12-31')
            LEFT JOIN representation_characteristics rc ON
                r.id = rc.representation_id AND
                COALESCE(r.start_date, '1900-01-01') >= COALESCE(rc.start_date, '1900-01-01') AND
                COALESCE(r.start_date, '1900-01-01') < COALESCE(rc.end_date, '9999-12-31')
            INNER JOIN post t ON
                a.post_id = t.id
            INNER JOIN organisation o ON
                t.organisation_id = o.id
            LEFT JOIN organisation_link ol1 ON
                o.id = ol1.predecessor_organisation_id AND
                ac.end_date = ol1.link_date
            LEFT JOIN organisation_link ol2 ON
                o.id = ol2.successor_organisation_id AND
                ac.start_date = ol2.link_date
            LEFT JOIN post_relationship pr ON
                pr.post_id = t.id
        WHERE
            ac.is_on_leave = 0 AND
            t.id IN (@role_ids) AND
            COALESCE(ac.end_date, '9999-12-31') > @start_date AND
            COALESCE(ac.start_date, '1900-01-01') <= @end_date
    ) q
) q
WHERE
    q.row_number = 1
GROUP BY
    q.person_id,
    q.group_name,
    q.organisation_link_id
ORDER BY
    MIN(COALESCE(q.start_date, '1900-01-01'))
