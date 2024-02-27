select
    case
        when t.name in ('Minister of State', 'Parliamentary Under Secretary of State') and @date2 = '9999-12-31' then 'Individuals serving ' || t.name || ', ' || o.short_name || ', ' || cast(strftime('%Y', @date1) as text(255)) || char(8211)
        when t.name in ('Minister of State', 'Parliamentary Under Secretary of State') then 'Individuals serving ' || t.name || ', ' || o.short_name || ', ' || cast(strftime('%Y', @date1) as text(255)) || char(8211) || cast(strftime('%Y', @date2) as text(255))
        when @date2 = '9999-12-31' then 'Individuals serving ' || t.name || ', ' || cast(strftime('%Y', @date1) as text(255)) || char(8211)
        else 'Individuals serving ' || t.name || ', ' || cast(strftime('%Y', @date1) as text(255)) || char(8211) || cast(strftime('%Y', @date2) as text(255))
    end Title,
    'Source: Institute for Government analysis of IfG Ministers Database, www.instituteforgovernment.org.uk/ifg-ministers-database' Source,
    @date1 [Axis min],
    @date2 [Axis max],
    null Notes
from post t
inner join organisation o on
    t.organisation_id = o.id
where
    t.id = @id
