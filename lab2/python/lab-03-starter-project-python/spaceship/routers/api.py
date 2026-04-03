from fastapi import APIRouter
import numpy as np

router = APIRouter()


@router.get('')
def hello_world() -> dict:
    return {'msg': 'Hello, World!'}


@router.get('/matrix-product')
def matrix_product() -> dict:
    rng = np.random.default_rng()
    matrix_a = rng.integers(0, 10, size=(10, 10))
    matrix_b = rng.integers(0, 10, size=(10, 10))
    product = matrix_a @ matrix_b

    return {
        'matrix_a': matrix_a.tolist(),
        'matrix_b': matrix_b.tolist(),
        'product': product.tolist(),
    }
