SELECT
    person_id,
    MIN(id_parliament) AS "image_id",
    MIN(minister_name) AS "minister_name",
    MIN(minister_short_name) AS "minister_short_name",
    MIN("mp_peer") AS "mp_peer",
    MIN(party) AS "party",
    MIN(role_id) AS "role_id",

    CASE
        WHEN MAX(CASE WHEN is_on_leave = 1 THEN 1 ELSE 0 END) = 1 THEN GROUP_CONCAT(role || ' (on leave)', '/')
        WHEN MAX(CASE WHEN is_acting = 1 THEN 1 ELSE 0 END) = 1 THEN GROUP_CONCAT(role || ' (acting)', '/')
        ELSE GROUP_CONCAT(role, '/')
    END AS "role",

    GROUP_CONCAT(department, '/') AS "department",
    MIN(rank) AS "rank",
    MIN(cabinet_status) AS "cabinet_status",
    MIN(start_date) AS "start_date",
    MAX(end_date) AS "end_date"
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
            p.id_parliament,
            p.name minister_name,
            p.short_name minister_short_name,
            CASE
                WHEN r.house = 'Commons' THEN 'MP'
                WHEN r.house = 'Lords' THEN 'Peer'
            END "mp_peer",
            rc.party AS "party",
            t.id role_id,
            t.name AS "role",
            t.rank_equivalence AS "rank",
            o.name AS "department",
            ac.id appointment_characteristics_id,
            ac.cabinet_status AS "cabinet_status",
            ac.is_on_leave AS "is_on_leave",
            ac.is_acting AS "is_acting",
            ac.leave_reason AS "leave_reason",
            ac.start_date AS "start_date",
            ac.end_date AS "end_date"
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
            -- Main filters
            role_id IN (@role_ids)

            AND
            COALESCE(ac.end_date, '9999-12-31') > @start_date

            AND
            COALESCE(ac.start_date, '1900-01-01') <= @end_date

            -- Secondary filters
            -- These need to use column aliases so the conditions are reusable across all 8 main queries.
            /*
            AND
            minister_name IN (@names)

            AND
            cabinet_status IN (@cabinet_statuses)

            AND
            mp_peer IN (@mp_peer)

            AND
            party IN (@party)

            AND
            rank IN (@rank)

            AND
            department IN (@department)
            */

    ) q
    ORDER BY
        COALESCE(q.start_date, '1900-01-01')
) q

GROUP BY
    person_id,
    group_name,
    organisation_link_id

HAVING
    row_number = 1

ORDER BY
    start_date ASC

-- Paged example
-- e.g. viewing page 2 of 10 results per page.
/*
LIMIT 10
OFFSET 10
*/
