# -*- coding: utf-8 -*-
from __future__ import unicode_literals

import factory

from flask.signals import Namespace

from factory.mongoengine import MongoEngineFactory
from faker import Faker

from udata.tests.factories import DatasetFactory

from .. import backends
from ..models import HarvestSource, HarvestJob

fake = Faker()


def dtfactory(start, end):
    return factory.LazyAttribute(
        lambda o: fake.date_time_between(start_date=start, end_date=end))


class HarvestSourceFactory(MongoEngineFactory):
    class Meta:
        model = HarvestSource

    name = factory.LazyAttribute(lambda o: fake.name())
    url = factory.LazyAttribute(lambda o: fake.url())
    description = factory.LazyAttribute(lambda o: fake.text())


class HarvestJobFactory(MongoEngineFactory):
    class Meta:
        model = HarvestJob

    created = dtfactory('-3h', '-2h')
    started = dtfactory('-2h', '-1h')
    ended = dtfactory('-1h', 'new')
    status = factory.fuzzy.FuzzyChoice(HarvestJob.status.choices)
    source = factory.SubFactory(HarvestSourceFactory)


ns = Namespace()

mock_initialize = ns.signal('backend:initialize')
mock_process = ns.signal('backend:process')

DEFAULT_COUNT = 3


@backends.register
class FactoryBackend(backends.BaseBackend):
    name = 'factory'

    def initialize(self):
        mock_initialize.send(self)
        for i in range(self.config.get('count', DEFAULT_COUNT)):
            self.add_item(i)

    def process(self, item):
        mock_process.send(self, item=item)
        return DatasetFactory.build(title='dataset-{0}'.format(item.remote_id))