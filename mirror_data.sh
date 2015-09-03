# This script contains commands to mirror data
# for the tests from external locations to CGAT
# internal locations.

# Mysql tables for test_ancestral_repeats
echo "import repeats from hg19 - single large table"
#mysqldump -h genome-mysql.cse.ucsc.edu -u genome --single-transaction hg19 rmsk | mysql -h gandalf -u genome hg19
echo "import repeats from mm9 - multiple tables"
#for x in `mysql -h genome-mysql.cse.ucsc.edu -u genome -A -e "show tables like '%rmsk'" mm9 -B -N`; do
#	mysqldump -h genome-mysql.cse.ucsc.edu -u genome --single-transaction mm9 $x | mysql -h gandalf -u genome mm9;
#done

# Mysql tables for annotations pipeline
echo "import cpgislands from hg19"
mysqldump -h genome-mysql.cse.ucsc.edu -u genome --single-transaction hg19 cpgIslandExt | mysql -h gandalf -u genome hg19
