import os.path
from glob import glob
from typing import cast
import torch
from ._zip_file import PackageZipFileReader, PackageZipFileWriter
import zipfile
from abc import ABC, abstractmethod

class TorchScriptPackageZipFileWriter(PackageZipFileWriter):
    """
    Class to allow PackageImporter to operate on unzipped packages. Methods
    copy the behavior of the internal PyTorchFileReader class (which is used for
    accessing packages in all other cases).

    N.B.: ScriptObjects are not depickleable or accessible via this DirectoryReader
    class due to ScriptObjects requiring an actual PyTorchFileReader instance.
    """

    def __init__(self, file_name):
        self.zip_file_writer = torch._C.PyTorchFileWriter(file_name)
        self.zip_file_writer.set_min_version(6)
        self.serializer = torch._C.ScriptModuleSerializer(self.zip_file_writer)

    def write_record(self, file_name, str_or_bytes, size):
        self.zip_file_writer.write_record(file_name, str_or_bytes, size)

    def get_serializer(self):
        return self.serializer

    def get_storage_context(self):
        return self.serializer.storage_context()

    def close(self):
        self.serializer.write_files()

class TorchScriptPackageZipFileReader(PackageZipFileReader):
    """
    Class to allow PackageImporter to operate on unzipped packages. Methods
    copy the behavior of the internal PyTorchFileReader class (which is used for
    accessing packages in all other cases).

    N.B.: ScriptObjects are not depickleable or accessible via this DirectoryReader
    class due to ScriptObjects requiring an actual PyTorchFileReader instance.
    """

    def __init__(self, file_name):
        self.zip_file_reader = torch._C.PyTorchFileReader(file_name)
        self.get_all_records()

    def get_record(self, name):
        return self.zip_file_reader.get_record(name)

    def has_record(self, path):
        return self.zip_file_reader.has_record(path)

    def get_all_records(self):
        return self.zip_file_reader.get_all_records()

    def get_zip_file_reader(self):
        return self.zip_file_reader

    def get_storage_from_record(self, name, numel, dtype):
        return self.zip_file_reader.get_storage_from_record(name, numel, dtype)

    def close(self):
        pass
