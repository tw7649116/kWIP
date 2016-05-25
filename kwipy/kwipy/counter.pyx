import numpy as np
cimport numpy as np
from bcolz import carray
cimport cython
from .constants import BCOLZ_CHUNKLEN


ctypedef unsigned long long int u64

# de Bruijn DNA sequences of k={2,3}, i.e. contain all 2/3-mers once
K2_DBS = 'AACAGATCCGCTGGTTA'
K3_DBS = 'AAACAAGAATACCACGACTAGCAGGAGTATCATGATTCCCGCCTCGGCGTCTGCTTGGGTGTTTAA'

cdef inline u64 mm64(u64 key, u64 seed):
    cdef u64 m = 0xc6a4a7935bd1e995
    cdef u64 r = 47

    cdef u64 h = seed ^ (8 * m)

    key *= m
    key ^= key >> r
    key *= m

    h ^= key
    h *= m

    return h


def iter_kmers(str seq not None, int k):
    '''Iterator over hashed k-mers in a string DNA sequence.
    '''
    cdef u64 n
    cdef u64 bitmask = 2**(2*k)-1  # Set lowest 2*k bits
    cdef u64 h = 0

    # For each kmer's end nucleotide, bit-shift, add the end and yield
    cdef u64 skip = 0
    for end in range(len(seq)):
        nt = seq[end]
        if skip > 0:
            skip -= 1
        if nt == 'A' or nt == 'a':
            n = 0
        elif nt == 'C' or nt == 'c':
            n = 1
        elif nt == 'G' or nt == 'g':
            n = 2
        elif nt == 'T' or nt == 't':
            n = 3
        else:
            skip = k
            continue
        h = ((h << 2) | n) & bitmask
        if end >= k - 1 and skip == 0:
            # Only yield once an entire kmer has been loaded into h
            yield h


cdef class Counter(object):
    cdef readonly u64 k
    cdef readonly u64 nt, ts, cvsize
    cdef u64 dtmax
    cdef np.ndarray cms, cv

    def __init__(self, k, cvsize=2e8):
        self.k = k
        self.nt, self.ts = (4, cvsize / 2)

        self.cvsize = cvsize
        dtype='u2'
        self.dtmax = 2**16 - 1

        if self.nt < 1 or self.nt > 10:
            raise ValueError("Too many or few tables. must be 1 <= nt <= 10")

        self.cms = np.zeros((self.nt, self.ts), dtype=dtype)
        self.cv = np.zeros(int(cvsize), dtype=dtype)

    @cython.boundscheck(False)
    @cython.overflowcheck(False)
    @cython.wraparound(False)
    cdef count(Counter self, u64 item):
        cdef u64 minv = <u64>-1
        cdef u64 hsh, v, i

        for tab in range(self.nt):
            hsh = mm64(item, tab)
            i = hsh % self.ts
            v = self.cms[tab, i]
            if v <= self.dtmax:
                v += 1
            if minv > v:
                minv = v
            self.cms[tab, i] = v
        self.cv[hsh % self.cvsize] = minv
        return minv

    @cython.boundscheck(False)
    @cython.overflowcheck(False)
    @cython.wraparound(False)
    cpdef get(Counter self, u64 item):
        cdef u64 hsh
        hsh = mm64(item, self.nt-1)
        return self.cv[hsh % self.cvsize]

    def consume(self, str seq not None):
        cdef long long hashv = 0
        for kmer in iter_kmers(seq, self.k):
            self.count(kmer)

    def save(self, str filename not None):
        carray(self.cv, rootdir=filename, mode='w',
               chunklen=BCOLZ_CHUNKLEN).flush()
