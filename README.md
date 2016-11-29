# PersianStemmingDataset
Persian Stemming data-set in order to evaluate new stemmers

## Description
There is no standard dataset for correctness evaluation of Persian stemming algorithms. In order to create a dataset for correctness evaluation of stemmers, we require a set of words with their stems. These datasets are automatically extracted from two manually stemmed corpora. The first dataset contains a collection of words and their stems, which has been extracted from the PerTreeBank corpus [1]. This corpus contains 4,689 distinct words. Moreover, in order to perform a better evaluation, we selected a large text corpus for the second dataset. The words and their stems of this dataset have been extracted from the Persian Dependency TreeBank corpus [2]. It contains 26,913 distinct words. These two datasets have good qualities in terms of the diversity of their Part-of-Speech tags.

## Tool
You can use the *evaluate.exe* in order to evalute your stemming results. It generates report based on your result. It supports all the metrics of stemming evalution such as *Accuracy*, *Percision*, *Recall*, *F-Measure*, *Understemming and Overstemming Errors*, *Commission and Ommission Errors*.

## Usage
Each stemming dataset is consist of three columns. The first column is the inflected word, the second is its stem and the third is its part-of-speech. You must append your stems to the fourth column. Then you can use below command.
```batch
Evaluate.exe "{your stemmed file path}" 1 3 {evaluation output file name}
```

---
## References
[1] Ghayoomi, M. (2012) Bootstrapping the Development of an HPSG-based Treebank for Persian. Linguistic Issues in Language Technology, 7.

[2] Rasooli, M. S., Moloodi, A., Kouhestani, M., and Minaei-Bidgoli, B. (2011) A syntactic valency lexicon for Persian verbs : The first steps towards Persian dependency treebank. 5th Language & Technology Conference (LTC) : Human Language Technologies as a Challenge for Computer Science and Linguistics, pp. 227–231.
