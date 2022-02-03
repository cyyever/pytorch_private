import os.path
from glob import glob
from ._zip_file import PackageZipFileReader


class DirectoryReader(PackageZipFileReader):
    """
    Class to allow PackageImporter to operate on unzipped packages. Methods
    copy the behavior of the internal PyTorchFileReader class (which is used for
    accessing packages in all other cases).

    N.B.: ScriptObjects are not depickleable or accessible via this DirectoryReader
    class due to ScriptObjects requiring an actual PyTorchFileReader instance.
    """

    def __init__(self, directory):
        self.directory = directory

    def get_record(self, name):
        filename = f"{self.directory}/{name}"
        with open(filename, "rb") as f:
            return f.read()

    def has_record(self, path):
        full_path = os.path.join(self.directory, path)
        return os.path.isfile(full_path)

    def get_all_records(
        self,
    ):
        files = []
        for filename in glob(f"{self.directory}/**", recursive=True):
            if not os.path.isdir(filename):
                files.append(filename[len(self.directory) + 1 :])
        return files

    def close():
        pass
