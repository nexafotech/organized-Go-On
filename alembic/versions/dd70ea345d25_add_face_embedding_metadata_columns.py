"""add_face_embedding_metadata_columns

Revision ID: dd70ea345d25
Revises: 396fe7a86a88
Create Date: 2026-09-25 14:58:04.184599

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'dd70ea345d25'
down_revision: Union[str, Sequence[str], None] = '396fe7a86a88'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema to add face embedding metadata columns."""
    with op.batch_alter_table('face_embeddings', schema=None) as batch_op:
        batch_op.add_column(sa.Column('model_name', sa.String(length=50), nullable=False, server_default='dlib_resnet'))
        batch_op.add_column(sa.Column('model_version', sa.String(length=20), nullable=False, server_default='v1'))
        batch_op.add_column(sa.Column('dimension', sa.Integer(), nullable=False, server_default='128'))
        batch_op.add_column(sa.Column('detector_name', sa.String(length=50), nullable=False, server_default='dlib_hog'))
        batch_op.add_column(sa.Column('distance_metric', sa.String(length=20), nullable=False, server_default='euclidean'))
        batch_op.add_column(sa.Column('quality_score', sa.Float(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    with op.batch_alter_table('face_embeddings', schema=None) as batch_op:
        batch_op.drop_column('quality_score')
        batch_op.drop_column('distance_metric')
        batch_op.drop_column('detector_name')
        batch_op.drop_column('dimension')
        batch_op.drop_column('model_version')
        batch_op.drop_column('model_name')
