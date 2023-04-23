import yaml
from robot.api import Failure, logger


def _yaml_get(parsed, key):
    key, _, remainder = key.partition('.')
    here = parsed[key]
    if remainder:
        return _yaml_get(here, remainder)
    return here


class YAML:

    def yaml_parse(self, data):
        return yaml.safe_load(data)

    def yaml_get(self, parsed, key):
        return _yaml_get(parsed, key)
