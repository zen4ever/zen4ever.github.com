Django, Sphinx and search by distance
#####################################
:date: 2010-06-10 08:44
:author: Andrii Kurinnyi 
:tags: django, sphinx, geo
:category: Web

Some of the projects I’ve been working on recently, required from me
implementing search by a zip code.
One of the approaches would be to use GeoDjango or geopy.
This will solve the problem of looking up object by distance, but most
of the time you want to have full-text search index on your models as
well. So, wouldn’t it be wonderful if our search engine supported
queries by distance?
Turns out that with `Sphinx`_ you can do precisely that.

Sphinx installation and integration with django are described in depth
in the following tutorials:

-  `In-Depth django-sphinx tutorial`_
-  `A Guide to Django full-text search with Sphinx and django-sphinx`_

The only thing I wanted to mention, is that you can also install Sphinx
with PostgreSQL. To do so you will need to have
*postgresql-server-8.3-devel* on Debian installed and configure sphinx
with *—with-pgsql* flag.

Now, let’s say you have a site with jobs.

.. code-block:: python

    class Job(models.Model):
        title = models.CharField(max_length=255)
        description = models.TextField()
        tags = TagField()
        latitude = models.FloatField()
        longitude = models.FloatField()

        search = SphinxSearch(
              index='jobs_job',
              weights={
                  'title':100,
                  'description':50,
                  'tags': 70, 
             })

If you run *./manage.py generate\_sphinx\_config jobs*, it will give you
basic index config.
You can tweak it by converting latitude and longitude to radians and
declaring them as attributes.

::

    source jobs_job
    {
        type                = pgsql
        sql_host            = localhost
        sql_user            = youruser
        sql_pass            = yourpassword
        sql_db              = sphinx_example
        sql_port            = 
        sql_query_pre       =
        sql_query_post      =
        sql_query           = \
            SELECT id, title, description, tags, radians(latitude) as latit, radians(longitude) as longit\
            FROM jobs_job
        sql_query_info      = SELECT * FROM `jobs_job` WHERE `id` = $id

        sql_attr_float      = latit
        sql_attr_float      = longit
    }

    index jobs_job
    {
        source          = jobs_job
        path            = /var/data/jobs_job
        docinfo         = extern
        morphology      = none
        stopwords       =
        min_word_len    = 2
        charset_type    = utf-8
        min_prefix_len  = 0
        min_infix_len   = 0
    }

Now you can use “geoanchor” attribute of the SphinxSearch object to
perform search by distance.
The only thing you need to remember, Sphinx expects your latitude and
longitude to be in radians,
and it returns distance in meters. 1 mile is approximately 1609.344
meters.
For example, if you want to search for all jobs in 10 mile radius from
given geographic point:

.. code-block:: python

    from django.core.management import setup_environ
    import settings

    setup_environ(settings)

    from jobs.models import Job

    import math

    def to_radians(latit, longit):
        return (math.radians(latit),math.radians(longit))

    latit, longit = to_radians(34.095259, -118.347997)

    mi = 1609.344

    job_list = (
         Job.search.geoanchor('latit', 'longit', latit, longit)
                   .filter(**{'@geodist__lt':10*mi})
                   .order_by('-@geodist')
    )

    print [x.sphinx.values() for x in job_list]

Geoanchor syntax requires you to specify names of the Sphinx attributes
for latitude and longitude.
You have them in your index config as ‘latit’ and ‘longit’.
Sphinx is using “magic” @geodist attribute to work with distance,
which doesn’t work with python syntax for function named arguments,
that’s why you have to use \*\*kwargs syntax in filter.

You can find full code of Django project on `GitHub`_.

UPDATE: Updated attribute names, so they won’t be similar to database
keywords, thanks to `@imns81`_


.. _Sphinx: http://sphinxsearch.com/docs/current.html
.. _In-Depth django-sphinx tutorial: http://www.davidcramer.net/code/79/in-depth-django-sphinx-tutorial.html
.. _A Guide to Django full-text search with Sphinx and django-sphinx: http://pkarl.com/articles/guide-django-full-text-search-sphinx-and-django-sp/
.. _GitHub: http://github.com/zen4ever/djangosphinx_example
.. _@imns81: http://twitter.com/imns81
