select
    id_ifg_website
from person
where
    display_name = @minister_name
order by
    display_name asc
